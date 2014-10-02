#!/bin/bash

LOGFILE="/var/log/db_sh.log";
## Restarting Environmental Parameters
. /etc/trm_std*
. /etc/rtrmx_inf*


function writeLog {
    stamp=`date | awk '{print $1,$2,$3,$4}'`
    echo [$stamp] $*
    echo [$stamp] $* >> $LOGFILE
}


writeLog " "
writeLog " "
writeLog " "
writeLog " ===========     Begin db.sh  ============================== "

trm_vip=`grep 3log_vip /etc/hosts | awk '{print $1}'`  > /dev/null
ifconfig -a | grep -w "addr:$trm_vip" > /dev/null
if [ $? -ne 0 ]
then
	writeLog "This is not the Active TRM , exiting...."
	exit 0
else
	writeLog "This is the Active TRM , Continue...."
fi


PVVMPlatform=`echo $1| tr '[:upper:]' '[:lower:]'`
Service_Mode_VoiceWriter=`echo $2| tr '[:upper:]' '[:lower:]'`
TYPE=$3
writeLog "Loading Environment"
. /etc/trm_stdprofile
. /etc/rtrmx_informix_env.sh
if [ "$TYPE" == 'IMAGE_TYPE' ]
then
    writeLog "Using Image Type"
	mapFile=/tmp/image_map
	EXE_CMD=$TRM_CMD/image_LOV_admin.pl
	db_col="ftt_field_val_num"
	CONF_FILE=image_LOV_config.ini
else
    writeLog "Using Handset Type"
	mapFile=/tmp/handset_map
	EXE_CMD=$TRM_CMD/handset_LOV_admin.pl
	db_col="ftt_field_val_char"
	CONF_FILE=handset_LOV_config.ini
fi

if [! -e $mapFile ]
then
   writeLog "ERROR:     $mapFile is missing!! Exiting...."
   exit 1
fi

if [ "$PVVMPlatform" == 'insight4' ] || [ "$Service_Mode_VoiceWriter" == 'none' ]
then
	writeLog "not reused"
	exit 0
fi

if [ ! -f $EXE_CMD ]
then
	writeLog "$EXE_CMD does not exist , Exiting...."
	exit 0
fi
file=$TRM_CONFIG/"$CONF_FILE"
if [ ! -f $file".oct" ]
then
        \mv $TRM_CONFIG/$CONF_FILE $TRM_CONFIG/CONF_FILE.oct
fi

###Backup table
BkupDate=`date '+%d%m%Y'`
BkupFile="/tmp/ftt_trans_field_Backup$BkupDate.unl"

su om -c  "echo \"unload to $BkupFile select * from ftt_field_trans;\"| /usr/informix/bin/dbaccess trm_db"
	
writeLog "Deleting ftt_field_trans table"
 su om -c "echo \"select '@@' ,ftt_field_val_desc  from ftt_field_trans where ftt_field_name='$TYPE';\"|dbaccess trm_db" > /tmp/1.txt
# su  om -c "echo \"select '@@' ,ftt_field_val_desc  from ftt_field_trans where ftt_field_name=\'$TYPE\';\"|dbaccess trm_db" > /tmp/1.txt
echo '[DELETE]' > $file


grep '^@@' /tmp/1.txt |cut -d" " -f2-100 > /tmp/stam
x=0
str='VALUE='
while read line
do
        if [ $x -eq 0 ]
        then
                str=$str"$line"
		x=1
        else
                str=$str";""$line"
        fi
        
done < /tmp/stam
writeLog "Editing $file"
echo $str >> $file
cat $file
$EXE_CMD
writeLog "$EXE_CMD"





###
echo '[MODIFY]' > $file".mod"
echo '[ADD]' > $file".add"

sqlStr="select '@@',ftt_field_val_desc ,$db_col from ftt_field_trans where ftt_field_name=\"$TYPE\" and ("

index=1
while read line
do
        value=`echo $line | awk '{print $1}'`
        if [ $index -eq 1 ]
        then
                sqlStr=$sqlStr" $db_col="$value
        else
                sqlStr=$sqlStr" or $db_col="$value
        fi
        index=`expr $index + 1 `



done < $mapFile
sqlStr=$sqlStr" );"
#echo $sqlStr
echo $sqlStr > /tmp/sql
# su  om -c "echo \"$sqlStr\" | dbaccess trm_db" > /tmp/1
su  om -c "cat /tmp/sql |  dbaccess trm_db" > /tmp/1
grep ^@@ /tmp/1 > /tmp/2
#cat /tmp/2
CURR_VAL="CURR_VAL="
NEW_VAL="NEW_VAL="
NEW_DESC="NEW_DESC="
VALUE="VALUE="
DESC="DESC="
while read line
do
        str=""
        value=`echo $line | awk '{print $1}'`
        grep $value /tmp/2 > /dev/null
        if [ $? -eq 0 ]
        then
                echo $value in DB will modify
                mapLine=`grep $value /tmp/2`
                count=`echo $mapLine | wc -w`
                #echo $mapLine
                #echo $count
                value=`echo $mapLine | cut -d" " -f $count`
                x=2
                count=`expr $count - 1`
                while [ $x -le $count ]
                do
                        str=$str" "`echo $mapLine | cut -d" " -f $x`
                        x=`expr $x + 1`


                done
                #echo value:$value
                #echo str:$str
                CURR_VAL=$CURR_VAL"$str"";"
                newName=`grep "^$value" $mapFile | cut -f2- -d" "`
                NEW_VAL=$NEW_VAL"\"$newName\""";"
                NEW_DESC=$NEW_DESC"$value"";"
        else
                DESC=$DESC"$value"";"
                temp=`grep "^$value" $mapFile | cut -f2- -d" "`
                VALUE=$VALUE"\"$temp\""";"

                echo $value not in DB will add
        fi


done < $mapFile
DESC=${DESC%?}
VALUE=${VALUE%?}
echo $CURR_VAL >> $file".mod"
echo $NEW_VAL >> $file".mod"
echo $NEW_DESC >> $file".mod"
echo $VALUE >> $file".add"
echo $DESC >> $file".add"

cat $file".mod" > $file
cat $file".add" >> $file
chown om:trmgroup $file
#echo '###################### Here Is The File ##################################'
#cat $file

writeLog "Adding new values to ftt_field_trans table"
$EXE_CMD
if [ $? -ne 0 ]
then
	writeLog "Failed to update DB"
else
    writeLog "DB was updated successfully"
fi
if [ -f $TRM_CONFIG/"$CONF_FILE".oct ]
then
	\mv $TRM_CONFIG/"$CONF_FILE".oct $TRM_CONFIG/"$CONF_FILE"
fi

writeLog " ===========     End db.sh  ============================== "
writeLog " "
