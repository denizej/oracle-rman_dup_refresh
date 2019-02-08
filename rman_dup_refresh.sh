#!/bin/bash

# set defaults
RETURN_STATUS=0
DEBUG_LEVEL=0
NO_PROMPT=0

function usage()
{
  echo
  echo "Usage: $(basename $1) [-help|-h] [-debug] [-noPromopt] {-system=SYSTEM} {-source_env=SOURCE_ENV} {-dest_env=DEST_ENV} [-func=FUNCTION_TO_EXEC]"
  echo "Where:"
  echo "  -help|-h         - Optional: Show this usage"
  echo "  -debug           - Optional: (default is off)"
  echo "  -noPrompt        - Optional: Setting this option will run with no prompts to the user (default is to prompt if an interactive session)"
  echo "  -system          - Required: Name of the system that forms the common prefix of the database SID"
  echo "  -source_env      - Required: Name of the source environment that forms the suffix of the database SID"
  echo "  -dest_env        - Required: Name of the destination environment that forms the suffix of the database SID"
  echo "  -func            - Optional: Name of a function to execute"
} # function usage

# check inputs
if [ $# -eq 0 ]; then
  echo -e "\nERROR: incorrect usage"
  usage $0
  exit 1
fi

# read inputs
while [[ $# -gt 0 ]]
do
  param=$(echo $1|cut -d= -f1)
  value=$(echo $1|cut -d= -f2)
  #echo param = $param
  #echo value = $value
  case $param in
        -help|-h)
                usage $0
                exit
                ;;
        -debug)
                #DEBUG_LEVEL="$value"
                DEBUG_LEVEL=1
                ;;
        -noPrompt)
                NO_PROMPT=1
                ;;
        -system)
                #SYSTEM="$value"
                SYSTEM=$(echo $value | tr '[:lower:]' '[:upper:]')
                ;;
        -source_env)
                SOURCE_ENV=$(echo $value | tr '[:lower:]' '[:upper:]')
                ;;
        -dest_env)
                DEST_ENV=$(echo $value | tr '[:lower:]' '[:upper:]')
                ;;
        -func)
                FUNCTION_TO_EXEC="$value"
                ;;
        *)
                echo -e "\nERROR: Invalid parameter: $param"
                usage $0
                exit 1
                ;;
  esac
  shift
done

# check required inputs
if [ -z $SYSTEM ]; then
  echo -e "\nERROR: -system required"
  usage $0
  exit 1
fi
if [ -z $SOURCE_ENV ]; then
  echo -e "\nERROR: -source_env required"
  usage $0
  exit 1
fi
if [ -z $DEST_ENV ]; then
  echo -e "\nERROR: -dest_env required"
  usage $0
  exit 1
fi


SCRIPT_NAME=$(basename $0|cut -d. -f1)

THIS_DIR=$(pwd)
cd $(dirname $0)
BASE_DIR=$(pwd)
cd $THIS_DIR

ENV_FILE=$BASE_DIR/$SCRIPT_NAME.env
FUNC_FILE=$BASE_DIR/$SCRIPT_NAME.func
#FUNC_FILE=$BASE_DIR/${SCRIPT_NAME}_${OSVER}_${ORAVER}.func

export SYS_DIR=$BASE_DIR/$SYSTEM
LOGS_DIR=$SYS_DIR/logs

if [ ! -r $ENV_FILE ]; then
  echo -e "\nERROR: cannot read environment file $ENV_FILE"
  usage $0
  exit 1
else
  # source in the main environment file
  . $ENV_FILE
fi

if [ ! -r $FUNC_FILE ]; then
  echo -e "\nERROR: cannot read function file $FUNC_FILE"
  usage $0
  exit 1
else
  # source in the function file
  . $FUNC_FILE
fi

if [ ! -d $LOGS_DIR ]; then
  mkdir -p $LOGS_DIR
  if [ ! $? -eq 0 ]; then
    echo -e "\nERROR: could not create directory $LOGS_DIR"
    exit 1
  fi
fi

if [ ! -d $SYS_DIR ]; then
  echo -e "\nERROR: cannot access directory $SYS_DIR"
  exit 1
elif [ ! -d $SYS_DIR/backups ]; then
  mkdir -p $SYS_DIR/backups
  if [ ! $? -eq 0 ]; then
    echo -e "\nERROR: could not create directory $SYS_DIR/backups"
    exit 1
  fi
fi

#COUNT=$(grep -c ^'function '${FUNCTION_TO_EXEC}'()' $FUNC_FILE)
COUNT=$(grep -c ^'function '${FUNCTION_TO_EXEC}'(){'  $FUNC_FILE)
if [ ! -z $FUNCTION_TO_EXEC ] && [ $COUNT -eq 0 ]; then
  usage $0
  echo -e "\nERROR: no function found called $FUNCTION_TO_EXEC"
  echo -e "\nThe list of functions available to be run are:\n"
  grep ^function $FUNC_FILE |awk {'print$2'}|cut -d\( -f1|sort|grep 'DB'
  echo
  exit 1
fi

if [ ! -d $POST_DB_REFRESH_SCRIPT_DIR ]; then
  echo -e "\nERROR: cannot access directory $POST_DB_REFRESH_SCRIPT_DIR"
  usage $0
  exit 1
fi

if [ ! -r $POST_DB_REFRESH_SCRIPT_DEF_FILE ]; then
  echo -e "\nERROR: cannot read file $POST_DB_REFRESH_SCRIPT_DEF_FILE"
  usage $0
  exit 1
fi

if [ ! -r $POST_DB_REFRESH_SCRIPT_SQL_FILE ]; then
  echo -e "\nERROR: cannot read file $POST_DB_REFRESH_SCRIPT_SQL_FILE"
  usage $0
  exit 1
fi


#MAIN_LOG_FILE=$LOGS_DIR/${SCRIPT_NAME}_${SOURCE_SID}_${DEST_SID}_${DATETIME}.log
touch $MAIN_LOG_FILE
if [ ! -r $MAIN_LOG_FILE ]; then
  echo -e "\nERROR: cannot write file $MAIN_LOG_FILE"
  usage $0
  exit 1
fi

##
## MAIN
##
time {

echo
echo "`date` - $SCRIPT_NAME started"
echo
echo "Main log file              : $MAIN_LOG_FILE" 
echo "RMAN log file              : $RMAN_LOG_FILE" 
echo "Results log file           : $RESULTS_LOG_FILE" 
echo "Source DB SID              : $SOURCE_SID" 
echo "Destination DB SID         : $DEST_SID" 
echo
echo "Post refresh SQL directory : $POST_DB_REFRESH_SCRIPT_DIR" 
echo "Post refresh SQL log file  : $POST_DB_REFRESH_SCRIPT_LOG_FILE" 
echo

# check if running in an interactive session or not
check_if_interactive
#echo INTERACTIVE = $INTERACTIVE



# check if a single fuinction is to be executed only
if [ -n "$FUNCTION_TO_EXEC" ]; then
  echo -e "\nNext: execute single function $FUNCTION_TO_EXEC then exit" 
  prompt_if_interactive $FUNCTION_TO_EXEC 
  log_return_status_pass_fail
  exit $RETURN_STATUS
fi


# start_oem_blackouts_DEST_DB
#echo -e "\nNext: start OEM Cloud Control blackouts for database $DEST_SID and its listener"
#NEXT_STEP=start_oem_blackouts_DEST_DB
#prompt_if_interactive $NEXT_STEP
#$NEXT_STEP
#log_return_status_pass_warning


# tnsping_SOURCE_DB
echo -e "\nNext: check that the SOURCE database $SOURCE_SID can be TNS pinged" 
NEXT_STEP=tnsping_SOURCE_DB
prompt_if_interactive $NEXT_STEP 
#$NEXT_STEP 
log_return_status_pass_fail
check_return_status_pass_fail


# tnsping_DEST_DB
echo -e "\nNext: check that the DESTINATION database $DEST_SID can be TNS pinged"
NEXT_STEP=tnsping_DEST_DB
#prompt_if_interactive $NEXT_STEP
$NEXT_STEP
log_return_status_pass_fail
check_return_status_pass_fail


# restart_DEST_DB_LSNR
echo -e "\nNext: restart the DESTINATION database $DEST_SID listener wth TNS_ADMIN = $TNS_ADMIN"
NEXT_STEP=restart_DEST_DB_LSNR
#prompt_if_interactive $NEXT_STEP
$NEXT_STEP
log_return_status_pass_warning


# status_DEST_DB_LSNR
echo -e "\nNext: check the status of the DESTINATION database $DEST_SID listener"
NEXT_STEP=status_DEST_DB_LSNR
#prompt_if_interactive $NEXT_STEP
$NEXT_STEP
log_return_status_pass_warning


# replace_orapw_file_DEST_DB
echo -e "\nNext: replace the password file for the DESTINATION database $DEST_SID"
NEXT_STEP=replace_orapw_file_DEST_DB
#prompt_if_interactive $NEXT_STEP
$NEXT_STEP
log_return_status_pass_warning


# restart_for_rman_DEST_DB
echo -e "\nNext: restart the DESTINATION database $DEST_SID to nomount state"
NEXT_STEP=restart_nomount_DEST_DB
prompt_if_interactive $NEXT_STEP
log_return_status_pass_fail
check_return_status_pass_fail

if [ ! $ORAVER == "12c" ]; then

# sysdba_test_SOURCE_DB
echo -e "\nNext: check that the SOURCE database $SOURCE_SID can be logged into using SQLplus as SYSDBA"
NEXT_STEP=sysdba_test_SOURCE_DB
#prompt_if_interactive $NEXT_STEP
$NEXT_STEP
log_return_status_pass_fail
check_return_status_pass_fail

else

# sysbackup_test_SOURCE_DB
echo -e "\nNext: check that the SOURCE database $SOURCE_SID can be logged into using SQLplus as SYSBACKUP"
NEXT_STEP=sysbackup_test_SOURCE_DB
#prompt_if_interactive $NEXT_STEP
$NEXT_STEP
log_return_status_pass_fail
check_return_status_pass_fail


# sysbackup_test_DEST_DB
echo -e "\nNext: check that the DESTINATION database $DEST_SID can be logged into using SQLplus as SYSBACKUP"
NEXT_STEP=sysbackup_test_DEST_DB
#prompt_if_interactive $NEXT_STEP
$NEXT_STEP
log_return_status_pass_fail
check_return_status_pass_fail

fi


# sysdba_test_DEST_DB
echo -e "\nNext: check that the DESTINATION database $DEST_SID can be logged into using SQLplus as SYSDBA"
NEXT_STEP=sysdba_test_DEST_DB
#prompt_if_interactive $NEXT_STEP
$NEXT_STEP
log_return_status_pass_fail
check_return_status_pass_fail


# drop_DEST_DB
echo -e "\nNext: drop the DESTINATION database $DEST_SID"
NEXT_STEP=drop_DEST_DB
prompt_if_interactive $NEXT_STEP
log_return_status_pass_fail
check_return_status_pass_fail


# restart_nomount_DEST_DB
echo -e "\nNext: restart the DESTINATION database $DEST_SID ready for RMAN duplication"
NEXT_STEP=restart_nomount_DEST_DB
#prompt_if_interactive $NEXT_STEP
$NEXT_STEP
log_return_status_pass_fail
check_return_status_pass_fail



# do_rman_dup_from_active_to_DEST_DB
echo -e "\nNext: start the RMAN duplication from $SOURCE_SID to recreate $DEST_SID"
if [ $ORAVER == "12c" ]; then
  NEXT_STEP=do_rman_dup_from_active_to_DEST_DB_12c
else
  NEXT_STEP=do_rman_dup_from_active_to_DEST_DB
fi
prompt_if_interactive $NEXT_STEP
log_return_status_pass_fail
check_return_status_pass_fail


# restart_DEST_DB_LSNR
echo -e "\nNext: restart the DESTINATION database $DEST_SID listener with the default TNS_ADMIN"
unset TNS_ADMIN
NEXT_STEP=restart_DEST_DB_LSNR
#prompt_if_interactive $NEXT_STEP
$NEXT_STEP
log_return_status_pass_warning


# disable_auto_maint_tasks_DEST_DB
#echo -e "\nNext: disable the automated maintenance tasks in $DEST_SID" 
#NEXT_STEP=disable_auto_maint_tasks_DEST_DB
#prompt_if_interactive $NEXT_STEP 
#$NEXT_STEP 
#log_return_status_pass_warning


# disable_archive_log_mode_DEST_DB
echo -e "\nNext: disable archive log mode in the new $DEST_SID" 
NEXT_STEP=disable_archive_log_mode_DEST_DB
#prompt_if_interactive $NEXT_STEP 
$NEXT_STEP 
log_return_status_pass_warning


# delete_all_archivelogs_DEST_DB
echo -e "\nNext: Delete all archivelogs for $DEST_SID database"
NEXT_STEP=delete_all_archivelogs_DEST_DB
prompt_if_interactive $NEXT_STEP
#$NEXT_STEP
log_return_status_pass_warning


# purge_recyclebin_DEST_DB
echo -e "\nNext: Purge recyclebin for $DEST_SID database"
NEXT_STEP=purge_recyclebin_DEST_DB
prompt_if_interactive $NEXT_STEP
#$NEXT_STEP
log_return_status_pass_warning


# set_ADR_purge_policies_DEST_DB
echo -e "\nNext: set the ADR short and long purge policies for the $DEST_SID database and listener"
NEXT_STEP=set_ADR_purge_policies_DEST_DB
#prompt_if_interactive $NEXT_STEP 
$NEXT_STEP 
log_return_status_pass_warning


# cleanup_audit_tabs_DEST_DB
echo -e "\nNext: Cleanup audit tables in the $DEST_SID database"
NEXT_STEP=cleanup_audit_tabs_DEST_DB
prompt_if_interactive $NEXT_STEP
#$NEXT_STEP
log_return_status_pass_warning


if [ $ORAVER == "12c" ]; then
# cleanup_unified_auditing_DEST_DB
echo -e "\nNext: Cleanup unified auditing in the $DEST_SID database"
NEXT_STEP=cleanup_unified_auditing_DEST_DB
prompt_if_interactive $NEXT_STEP
#$NEXT_STEP
log_return_status_pass_warning
fi


# reset_RMAN_config_DEST_DB
echo -e "\nNext: reset RMAN configuration for the $DEST_SID database"
NEXT_STEP=reset_RMAN_config_DEST_DB
#prompt_if_interactive $NEXT_STEP
$NEXT_STEP
log_return_status_pass_warning


# recreate_DB_dirs_DEST_DB
echo -e "\nNext: recreate any database directories that have $SOURCE_SID in the path"
NEXT_STEP=recreate_DB_dirs_DEST_DB
#prompt_if_interactive $NEXT_STEP
$NEXT_STEP
log_return_status_pass_warning


# disable_all_non_system_scheduler_jobs_DEST_DB
#echo -e "\nNext: disable all non system DBMS Scheduler jobs in $DEST_SID database"
#NEXT_STEP=disable_all_non_system_scheduler_jobs_DEST_DB
#prompt_if_interactive $NEXT_STEP
#log_return_status_pass_warning


# break_all_non_system_db_jobs_DEST_DB
#echo -e "\nNext: break all non system database jobs in $DEST_SID database"
#NEXT_STEP=break_all_non_system_db_jobs_DEST_DB
#prompt_if_interactive $NEXT_STEP
#log_return_status_pass_warning


# execute_post_DB_refresh_script
echo -e "\nNext: execute the system and environment specific post DB refresh script against $DEST_SID database"
NEXT_STEP=execute_post_DB_refresh_script
prompt_if_interactive $NEXT_STEP
log_return_status_pass_warning


# do_rman_full_backup_DEST_DB
#echo -e "\nNext: perform a full cold backup of the $DEST_SID database"
#NEXT_STEP=do_rman_full_backup_DEST_DB
#prompt_if_interactive $NEXT_STEP
#log_return_status_pass_warning


# stop_oem_blackouts_DEST_DB
#echo -e "\nNext: stop OEM Cloud Control blackouts for database $DEST_SID and its listener"
#NEXT_STEP=stop_oem_blackouts_DEST_DB
#prompt_if_interactive $NEXT_STEP
#$NEXT_STEP
#log_return_status_pass_warning


echo
cat $RESULTS_LOG_FILE

echo
echo "Main log file              : $MAIN_LOG_FILE"
echo "RMAN log file              : $RMAN_LOG_FILE"
echo "Results log file           : $RESULTS_LOG_FILE"
echo "Source DB SID              : $SOURCE_SID"
echo "Destination DB SID         : $DEST_SID"
echo
echo "Post refresh SQL directory : $POST_DB_REFRESH_SCRIPT_DIR"
echo "Post refresh SQL log file  : $POST_DB_REFRESH_SCRIPT_LOG_FILE"
echo
echo "`date` - $SCRIPT_NAME finished"

send_email

rm $TEMP_LOG_FILE > /dev/null 2>&1

} 2>&1 | tee -a $MAIN_LOG_FILE


