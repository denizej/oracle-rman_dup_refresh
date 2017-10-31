#!/bin/bash

USAGE="
USAGE: `basename $0` <SYSTEM> <SOURCE_ENV> <DEST_ENV> [FUNCTION_TO_EXEC]\n
EG: - `basename $0` ban stby p2\n
OR: - `basename $0` ban prod pprd\n
OR: - `basename $0` ban stby dev list_all_functions\n
"


if [ $# -lt 3 ]; then
  echo "ERROR: incorrect usage"
  echo -e $USAGE
  #echo "  USAGE: `basename $0` <SYSTEM> <SOURCE_ENV> <DEST_ENV>"
  #echo "example: `basename $0` ban prod pprd"
  exit 1
fi

SCRIPT_NAME=`basename $0|cut -d. -f1`

SYSTEM=`echo $1 | tr '[:lower:]' '[:upper:]'`
SOURCE_ENV=`echo $2 | tr '[:lower:]' '[:upper:]'`
DEST_ENV=`echo $3 | tr '[:lower:]' '[:upper:]'`

FUNCTION_TO_EXEC=$4

THIS_DIR=`pwd`
cd `dirname $0`
BASE_DIR=`pwd`
cd $THIS_DIR

ENV_FILE=$BASE_DIR/$SCRIPT_NAME.env
FUNC_FILE=$BASE_DIR/$SCRIPT_NAME.func
#FUNC_FILE=$BASE_DIR/${SCRIPT_NAME}_${OSVER}_${ORAVER}.func

export SYS_DIR=$BASE_DIR/$SYSTEM
LOGS_DIR=$SYS_DIR/logs

if [ ! -r $ENV_FILE ]; then
  echo ERROR: cannot read environment file $ENV_FILE
  echo -e $USAGE
  exit 1
else
  # source in the main environment file
  . $ENV_FILE
fi

if [ ! -r $FUNC_FILE ]; then
  echo "ERROR: cannot read function file $FUNC_FILE"
  echo -e $USAGE
  exit 1
else
  # source in the function file
  . $FUNC_FILE
fi

if [ ! -d $LOGS_DIR ]; then
  mkdir -p $LOGS_DIR
  if [ ! $? -eq 0 ]; then
    echo ERROR: could not create directory $LOGS_DIR
    exit 1
  fi
fi

if [ ! -d $SYS_DIR ]; then
  echo "ERROR: cannot access directory $SYS_DIR"
  echo -e $USAGE
  exit 1
elif [ ! -d $SYS_DIR/backups ]; then
  mkdir -p $SYS_DIR/backups
  if [ ! $? -eq 0 ]; then
    echo "ERROR: could not create directory $SYS_DIR/backups"
    exit 1
  fi
fi

COUNT=`grep -c ^'function '${FUNCTION_TO_EXEC}'()' $FUNC_FILE`
if   [ $# -eq 4 ] && [ $COUNT -gt 1 ]; then
  echo -e $USAGE
  echo -e "\nERROR: please be more specific as $FUNCTION_TO_EXEC matched $COUNT possible functions"
  echo -e "\nThe list of functions are:\n"
  grep ^function $FUNC_FILE |awk {'print$2'}|cut -d\( -f1|sort|grep 'DB'
  echo
  exit 1
elif [ $# -eq 4 ] && [ $COUNT -eq 0 ]; then
  echo -e $USAGE
  echo -e "\nERROR: no function found called $FUNCTION_TO_EXEC"
  echo -e "\nThe list of functions are:\n"
  grep ^function $FUNC_FILE |awk {'print$2'}|cut -d\( -f1|sort|grep 'DB'
  echo
  exit 1
elif [ $# -eq 3 ]; then 
  unset FUNCTION_TO_EXEC
fi

if [ ! -d $POST_DB_REFRESH_SCRIPT_DIR ]; then
  echo "ERROR: cannot access directory $POST_DB_REFRESH_SCRIPT_DIR"
  echo -e $USAGE
  exit 1
fi

if [ ! -r $POST_DB_REFRESH_SCRIPT_DEF_FILE ]; then
  echo "ERROR: cannot read file $POST_DB_REFRESH_SCRIPT_DEF_FILE"
  echo -e $USAGE
  exit 1
fi

if [ ! -r $POST_DB_REFRESH_SCRIPT_SQL_FILE ]; then
  echo "ERROR: cannot read file $POST_DB_REFRESH_SCRIPT_SQL_FILE"
  echo -e $USAGE
  exit 1
fi


#MAIN_LOG_FILE=$LOGS_DIR/${SCRIPT_NAME}_${SOURCE_SID}_${DEST_SID}_${DATETIME}.log
touch $MAIN_LOG_FILE
if [ ! -r $MAIN_LOG_FILE ]; then
  echo "ERROR: cannot write file $MAIN_LOG_FILE"
  echo -e $USAGE
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

RETURN_STATUS=0



# check if a single fuinction is to be executed only
if [ -n "$FUNCTION_TO_EXEC" ]; then
  echo -e "\nNext: execute single function $FUNCTION_TO_EXEC then exit" 
  prompt_if_interactive $FUNCTION_TO_EXEC 
  log_return_status_pass_fail
  exit $RETURN_STATUS
fi


# start_oem_blackouts_DEST_DB
echo -e "\nNext: start OEM Cloud Control blackouts for database $DEST_SID and its listener"
NEXT_STEP=start_oem_blackouts_DEST_DB
prompt_if_interactive $NEXT_STEP
#$NEXT_STEP
log_return_status_pass_warning


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
NEXT_STEP=do_rman_dup_from_active_to_DEST_DB
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
echo -e "\nNext: disable the automated maintenance tasks in $DEST_SID" 
NEXT_STEP=disable_auto_maint_tasks_DEST_DB
prompt_if_interactive $NEXT_STEP 
#$NEXT_STEP 
log_return_status_pass_warning


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
echo -e "\nNext: disable all non system DBMS Scheduler jobs in $DEST_SID database"
NEXT_STEP=disable_all_non_system_scheduler_jobs_DEST_DB
prompt_if_interactive $NEXT_STEP
log_return_status_pass_warning


# break_all_non_system_db_jobs_DEST_DB
echo -e "\nNext: break all non system database jobs in $DEST_SID database"
NEXT_STEP=break_all_non_system_db_jobs_DEST_DB
prompt_if_interactive $NEXT_STEP
log_return_status_pass_warning


# execute_post_DB_refresh_script
echo -e "\nNext: execute the system and environment specific post DB refresh script against $DEST_SID database"
NEXT_STEP=execute_post_DB_refresh_script
prompt_if_interactive $NEXT_STEP
log_return_status_pass_warning


# stop_oem_blackouts_DEST_DB
echo -e "\nNext: stop OEM Cloud Control blackouts for database $DEST_SID and its listener"
NEXT_STEP=stop_oem_blackouts_DEST_DB
prompt_if_interactive $NEXT_STEP
#$NEXT_STEP
log_return_status_pass_warning


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


