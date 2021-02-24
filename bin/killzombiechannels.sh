#!/bin/bash

t=$(date +%s)
let "tm1=$t-18000"

sql_channels="DELETE FROM channels WHERE created_epoch < $tm1"  
sql_calls="DELETE FROM calls WHERE call_created_epoch < $tm1"  

/usr/bin/sqlite3 /usr/local/freeswitch/db/core.db "$sql_channels"
/usr/bin/sqlite3 /usr/local/freeswitch/db/core.db "$sql_calls"
