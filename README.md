# oracle-rman_dup_refresh
date: 2017-10-31
author: Josh Denize
Note: rman_dup_fresh is a scripted Oracle Database refresh or clone process using the RMAN duplicate from active method

USAGE: rman_dup_refresh.sh <SID_PREFIX> <SOURCE_ENV> <DEST_ENV> [FUNCTION_TO_EXEC]
 EG: - rman_dup_refresh.sh josh c1 c2
 OR: - rman_dup_refresh.sh josh c2 c3
 OR: - rman_dup_refresh.sh josh c2 c3 list_all_functions
