#!/bin/sh
LOCAL_HOSTNAME=`hostname`
CURRENT_UP_ORACLE=`hastatus -sum | grep Oracle | grep ONLINE | awk '{print $3}'`

if [ "$CURRENT_UP_ORACLE" = "$LOCAL_HOSTNAME" ]; then
        mkdir -p /data/oracle_backup/SWconf/unit/configuration
        chmod -R 777 /data/oracle_backup/SWconf
fi

CURRENT_UP_COUNTERS=`hastatus -sum | grep Counters | grep ONLINE | awk '{print $3}'`

if [ "$CURRENT_UP_COUNTERS" = "$LOCAL_HOSTNAME" ]; then
        chmod -R 777 /data/counters
fi