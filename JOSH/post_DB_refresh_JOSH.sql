set heading on
set verify off
set timing off
set feedback on
set serveroutput on
set echo on

whenever sqlerror CONTINUE

select '&SCRIPT_DIR'  "Post Refresh Script Dir" from dual;

define SCRIPT1='&DEST_SID._script1.sql'
define SCRIPT2='&DEST_SID._script2.sql'

@&SCRIPT_DIR/&SCRIPT1
@&SCRIPT_DIR/&SCRIPT2

