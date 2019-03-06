# oracle-rman_dup_refresh
date: 2017-10-31
author: Josh Denize
Note: rman_dup_fresh is a scripted Oracle Database refresh or clone process using the RMAN duplicate from active method

Usage: 
rman_dup_refresh.sh -system=$SYSTEM -source_env=$SOURCE_ENV -dest_env=$DEST_ENV [-func=$FUNCTION_TO_EXEC] [-help|-h] [-debug] [-noPrompt]

Where:
  -system          - Required: Name of the system that forms the common prefix of the database SID
  -source_env      - Required: Name of the source environment that forms the suffix of the database SID
  -dest_env        - Required: Name of the destination environment that forms the suffix of the database SID
  -func            - Optional: Name of a function to execute
  -noPrompt        - Optional: Setting this option will run with no prompts to the user (default is to prompt if an interactive session)
  -debug           - Optional: (default is off)
  -help|-h         - Optional: Show this usage
