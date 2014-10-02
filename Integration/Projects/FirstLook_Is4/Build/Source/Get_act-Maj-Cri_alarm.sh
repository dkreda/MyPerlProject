#!/bin/sh
echo "These are the critical and major alarms from the last 6 hours"
echo " 
rem  
rem ===================================================================
rem Version    : V1.0
rem Create     : 28/08/2012
rem Author     : Davy Laronne
rem Description: This SQL script download the active major and critical
rem alarm messsages for the last 6 hours from OVO database.
rem ===================================================================
rem 
 
 	set tab off
 	set Verify Off
        set heading off
        set linesize 4000
        set pagesize 0
        set feedback off
        set newpage 0;
        ttitle off;
 
   column SEVERITY format A8
   column NAME format A10
   column MSGGRP format A15
   column APPL format A10
   column OBJECT format A25
   column SERVICE format A25
   column MSGTEXT format A3000
   
rem opc_act_messages.message_number AS MSG_ID,
rem column MSG_ID format A40
 
  select 
TO_CHAR(LOCAL_LAST_TIME_RECEIVED, 'DD-MON-YYYY HH24:MI:SS'),TO_CHAR(LOCAL_CREATION_TIME, 'DD-MON-YYYY HH24:MI:SS'),
decode(opc_act_messages.severity,1,'unknown',2,'normal',4,'warning',16,'minor',32,'Major',8,'critical') AS SEVERITY,
opc_node_names.node_name AS NAME,
substr(opc_act_messages.message_group,1,30) AS MSGGRP,
opc_act_messages.application AS APPL,
opc_act_messages.object AS OBJECT,
opc_act_messages.service_name AS SERVICE,
substr(opc_msg_text.text_part,1,150) AS MSGTEXT
  from opc_act_messages,opc_node_names,opc_msg_text
  where opc_node_names.NODE_ID = opc_act_messages.NODE_ID  AND opc_msg_text.MESSAGE_NUMBER = opc_act_messages.MESSAGE_NUMBER AND opc_msg_text.ORDER_NUMBER = 1
AND opc_act_messages.ACKN_FLAG = 0 and LOCAL_LAST_TIME_RECEIVED > SYSDATE-(6/24)" > /etc/opt/OV/share/conf/OpC/mgmt_sv/reports/C/name.sql

if [ $# -gt 1 ]
then
if [ $1 = "-s" ]
then
case $2 in
"unknown")
        SEVERITY=1
;;
"normal")
        SEVERITY=2
;;
"warning")
        SEVERITY=4
;;
"minor")
        SEVERITY=16
;;
"major")
        SEVERITY=32
;;
"critical")
        SEVERITY=8
;;
esac    
	echo "AND opc_act_messages.severity = $SEVERITY" >> /etc/opt/OV/share/conf/OpC/mgmt_sv/reports/C/name.sql	
fi
fi
echo ";
quit;
" >> /etc/opt/OV/share/conf/OpC/mgmt_sv/reports/C/name.sql
/opt/OV/bin/OpC/call_sqlplus.sh name
