#!/bin/sh


grep REFUSE /opt/criticalpath/global/filters/default > /dev/null
if [ $? -eq 0 ]; then 
	grep mte /opt/criticalpath/global/filters/default > /dev/null
	if [ $? -eq 0 ]; then 
		echo "Relaying for mte is already configured - skipping"
	else 
		echo 'ACCEPT LBL \"message to *.mte\" RELAY-TO \"*.mte\"' > /tmp/relay.tmp
		cat /opt/criticalpath/global/filters/default >> /tmp/relay.tmp
		cp -f /tmp/relay.tmp /opt/criticalpath/global/filters/default
		rm -f /tmp/relay.tmp
		/usr/cti/babysitter/MamCMD stop SMTP
		/usr/cti/babysitter/MamCMD start SMTP
	fi
else
	echo "no REFUSE in filter leaving this as is"
fi