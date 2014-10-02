#!/bin/sh

Type=`uname`
echo "OSType:${Type}"
OSType=`echo $Type | tr '[a-z]' '[A-Z]'`
fileName=""
if [ "$OSType" = "LINUX" ]; then	
	fileName="/etc/sudoers"
else
	fileName="/usr/local/etc/sudoers"
fi

echo "Checking the sudoers file for the consistency....."
COUNT=`grep "BSUSER=bsuser" $fileName | wc -l`

if [ $COUNT -ne 0 ]; then
	echo "Entry for the bsuser already exists....."
	echo "Totally $COUNT duplicate entries found....."
	echo "Removing the entry....."

	cat $fileName | sed -e '/^Defaults:bsuser !syslog/d' > /usr/tmp/sudoersbak
	mv -f /usr/tmp/sudoersbak $fileName

	cat $fileName | sed -e '/^Cmnd_Alias BSCMD=/d' > /var/tmp/sudoersbak
	mv -f /var/tmp/sudoersbak $fileName

	cat $fileName | sed -e '/^BSUSER ALL/d' > /usr/tmp/sudoersbak
	mv -f /usr/tmp/sudoersbak $fileName

	cat $fileName | sed -e '/^User_Alias BSUSER/d' > /usr/tmp/sudoersbak
	mv -f /usr/tmp/sudoersbak $fileName

	cat $fileName | sed -e '/^%bsgroup ALL/d' > /usr/tmp/sudoersbak
	mv -f /usr/tmp/sudoersbak $fileName

	cp -f $fileName /usr/tmp/sudoers
	cat /usr/tmp/sudoers | sed -e 's/:bsuser,/:/' | sed -e 's/:bsuser//' | sed -e 's/Defaults\t!requiretty/Defaults\trequiretty/' > $fileName
	rm -rf /usr/tmp/sudoers

	chmod 440 $fileName
	
	COUNT=`grep "BSUSER=bsuser" $fileName | wc -l`
	if [ $COUNT -eq 0 ]; then
		echo "Entry for the bsuser removed....."
	else
		exit 1;
	fi
else 
	echo "Entry for the bsuser not found ....."
fi
