#!/bin/sh

upgrade_for_linux()
{
export JAVA_HOME=/usr/local/java
export PATH=$PATH:$JAVA_HOME/bin

echo "Upgrading babysitter..................."
echo "Checking dependencies..........."

core_kit="/usr/tmp/babysitter-ic-4.1.1.3-01.i386.rpm"
upgrade_kit="/usr/tmp/UPG-KIT-babysitter-ic-4.1.1.3-01.i386.rpm"
alreadyInstalledUpgradeKit=`rpm -qa | grep -i UPG-KIT-babysitter`    # check upgrade kit
installed_kit=`rpm -qa | grep -i baby | grep -v UPG`

if [ ! -f $core_kit ]; then
     echo "error: open of $core_kit failed: No such file or directory"
     echo "babysitter kit  not added - rpm installation failed"
     echo "Upgradation of <babysitter> cannot be done....... EXITING"
     exit 1
fi

if [ ! -f $upgrade_kit ]; then
     echo "error: open of $upgrade_kit failed: No such file or directory"
     echo "Upgrade kit of babysitter not added -  installation failed"
     echo "Upgradation of <babysitter> cannot be done....... EXITING"
     exit 1
fi

rpm --test -U $upgrade_kit >> /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Already installed upgrade kit - $alreadyInstalledUpgradeKit is newer than or same to the current upgrade kit - $upgrade_kit, Exiting !!!"
	exit 0;
fi

rpm --test -U $core_kit >> /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Already installed kit - $installed_kit is newer than or same to the current kit - $core_kit, Exiting !!!"
	exit 0;
fi

# name of the answer file for upgradation
answer_file_name="/usr/tmp/bs_answer_file"
# Variable to hold the java executable path
java_executable=''
if [ ! -f $answer_file_name ]
then
        echo "bs_answer_file not found in the /usr/tmp, Aborting upgradation......"
        exit 1
fi

# Pick the Java path from answer file.
java_executable=`cat $answer_file_name | grep '^JAVA_PATH=' | head -1 | awk -F = '{print $2}' | tr -d '\t [:space:]'`
if [ ! -f "$java_executable" ]; then
        echo "No Java runtime found. Aborting upgradation....."
        echo "Reconfigure the JAVA_PATH correctly in the bs_answer_file and try again....."
        exit 1
fi

java_ver_file="/usr/tmp/java.ver"
$java_executable -version 2> $java_ver_file
if [ $? -ne 0 ]; then
   echo "No Java runtime found. Aborting upgradation....."
   echo "Reconfigure the JAVA_PATH correctly in the bs_answer_file and try again....."
   exit 1
fi
java_installed=`cat $java_ver_file | head -1 |cut -d '"' -f2 | cut -d "." -f1-2`
rm -rf $java_ver_file

if [ "$java_installed" = "" ];
then
   echo "No Java runtime found. Aborting upgradation....."
   echo "Reconfigure the JAVA_PATH correctly in the bs_answer_file and try again....."
   exit 1
fi

java_required=1.5
result=`echo "$java_required <= $java_installed" | bc`
if [ "$result" -eq 0 ]; then # 1 == true
  echo "Babysitter-4.1.1.3 requires java version 1.5 or later. Aborting upgradation.....\n"
  echo "Reconfigure the JAVA_PATH correctly in the bs_answer_file and try again....."
  exit 1
fi

if [ "$java_executable" != "/usr/local/java/bin/java" ];
then
	# JAVA executable path can be a symbolic link.
	java_executable=`readlink -f "$java_executable"`
	# Set JRE_HOME
	jre_home=`echo "$java_executable" | awk -F /bin/java '{print $1}'`
	# Link the specified Java to /usr/local/java
	rm -f  /usr/local/java
	ln -sf $jre_home /usr/local/java
	if [ ! -f "/usr/local/java/bin/java" ]; then
        echo "Unable to create link /usr/local/java. Aborting upgradation....."
		exit 1
	fi
fi

if [ $alreadyInstalledUpgradeKit ]; then
    echo "Upgrade kit of Babysitter is already installed. Uninstalling it..."
	rpm -e $alreadyInstalledUpgradeKit
	if [ $? -ne 0 ]; then
	    echo "Problem in uninstalling UPG-KIT-babysitter. Exiting..."
	    exit 1
	fi
fi

rpm -qa | grep -i babysitter | grep -v UPG-KIT-babysitter # check core kit

if [ $? -ne 0 ]; then
if [ -d /usr/cti/babysitter ] || [ -d /usr/cti/apps/babysitter ]; then
   echo "Babysitter was installed with Octopus(Unziping .gz file)"
elif [ $? -ne 0 ]; then
    echo "Babysitter rpm not installed"
    echo "Upgradation of <babysitter> cannot be done....... EXITING"
    exit 1
fi
fi

Babwatchpid=`ps -ef| grep -v grep | grep -v babysitter.jar |grep -i babwatch.jar | awk '{print $2}' | xargs`
if [ -n "$Babwatchpid" ]
then
kill -9 $Babwatchpid
fi

Babypid=`ps -ef| grep -v grep | grep -v babwatch.jar |grep -i babysitter.jar | awk '{print $2}' | xargs`
if [ -n "$Babypid" ]
then
kill -9 $Babypid
fi


echo "Installing Upgrade package of babysitter...."
rpm -U $upgrade_kit

if [ $? -ne 0 ]; then
    echo "Upgrade kit of babysitter not added - rpm installation failed"
    exit 1
fi

echo "Log details written to /usr/cti/merge/babysitter/log/babysitter_upgrade.log"

/usr/cti/merge/babysitter/merge_utility/bin/copyToTarget.sh
/usr/cti/merge/babysitter/merge_utility/bin/merge.sh

if [ $? -ne 0 ]; then
    echo "Unable to perform merge /usr/cti/merge/babysitter/merge_utility/bin/merge.sh failed"
    exit 1
fi

#Added by Rahul for Password Encryption/Decryption bug(PSG00486282)

password=`cat /usr/cti/conf/babysitter/Babysitter.ini | grep -i "AuthPassword" | cut -d "=" -f2`

if [ "$password" != "$null" ]; then
  AuthPasswordLegacy=`/usr/cti/babysitter/MamCMD decrypt $password`
fi

echo "Removing old babysitter package..........."

if [ "$installed_kit" == "babysitter-ic-4.0.0.0-03" ] || [ "$installed_kit" == "babysitter-ic-4.0.0.0-02" ] || [  "$installed_kit" == "Babysitter-4.0.0.0-01" ]; then

    mkdir /usr/cti/conf/backuptmp

    mv /usr/cti/conf/babysitter/* /usr/cti/conf/backuptmp/

    rm -rf /usr/cti/conf/backuptmp/ApplicationsBabysitter.xml
    rm -rf /usr/cti/conf/backuptmp/ApplicationsBabysitter.scm
    rm -rf /usr/cti/conf/backuptmp/ApplicationsBabysitter.xsd
    rm -rf /usr/cti/conf/backuptmp/Babysitter.ini
    rm -rf /usr/cti/conf/backuptmp/Babysitter.scm
    rm -rf /usr/cti/conf/backuptmp/Babysitter.xsd
    rm -rf /usr/cti/conf/backuptmp/log4j.properties
    rm -rf /usr/cti/conf/backuptmp/kfiles

fi
if [ "$installed_kit" != "" ]; then
   rpm -e $installed_kit # remove already installed kit

   if [ $? -ne 0 ]; then
    echo "RPM babysitter not removed - rpm remove failed"
    exit 1
   fi
 elif [ -d /usr/cti/babysitter ] || [ -d /usr/cti/apps/babysitter ]; then
    Babwatchpid=`ps -ef| grep -v grep | grep -i /usr/cti/babysitter/Babwatch | awk '{print $2}' | xargs`
	if [ -n "$Babwatchpid" ]; then
	   kill -9 $Babwatchpid
	fi

    Babypid=`ps -ef| grep -v grep | grep -i /usr/cti/babysitter/Babysitter | awk '{print $2}' | xargs`
	if [ -n "$Babypid" ]; then
	   kill -9 $Babypid
	fi

	Babypid=`ps -ef| grep -v grep | grep -i /usr/cti/babysitter/.babysitter | awk '{print $2}' | xargs`
	if [ -n "$Babypid" ]; then
	   kill -9 $Babypid
	fi

   if [ -d /usr/cti/babysitter ]; then
     rm -rf /usr/cti/babysitter
   fi

   if [ -d /var/cti/logs/babysitter ]; then
     rm -rf /var/cti/logs/babysitter
   fi
fi

echo "Installing new babysitter package.........."
rpm -U $core_kit # install core kit

if [ $? -ne 0 ]; then
    echo "RPM babysitter not added - rpm install failed"
    exit 1
fi
echo "****************************************"
echo "  Babysitter Installed Successfully"
echo "****************************************"

/usr/cti/merge/babysitter/merge_utility/bin/copyToSource.sh

if [ -d /usr/cti/conf/backuptmp ]; then
  mv /usr/cti/conf/backuptmp/* /usr/cti/conf/babysitter/
  rm -rf /usr/cti/conf/backuptmp
fi

if [ "$AuthPasswordLegacy" != "$null" ]; then
 AuthPasswordNG=`/usr/cti/babysitter/MamCMD encrypt $AuthPasswordLegacy` # encrypt the legacy password through BS-NG
     if [ $? -ne 0 ]; then
         AuthPasswordNG="yBVfRvihbk68qkgN3MveVA=="
     fi
     if [[ "$AuthPasswordNG" == WARNING!!!* ]]; then
         AuthPasswordNG="yBVfRvihbk68qkgN3MveVA=="
     fi
 fi

if [ "$AuthPasswordNG" != "$null" ]; then
   sed -e 's#AuthPassword='$password'#AuthPassword='$AuthPasswordNG'#g' /usr/cti/conf/babysitter/Babysitter.ini > /usr/tmp/tmp_Babysitter.ini
   mv /usr/tmp/tmp_Babysitter.ini /usr/cti/conf/babysitter/Babysitter.ini
   chmod  740 /usr/cti/conf/babysitter/Babysitter.ini
fi

#pick the value of StartOnEnd from answer file
start_bs=`cat $answer_file_name | grep '^StartOnEnd=' | head -1 | awk -F = '{print $2}' | tr -d '\t [:space:]' | tr '[:upper:]' '[:lower:]'`
if [ "$start_bs" != "false" ]; then
    /etc/init.d/babysitter start
fi

sleep 4
echo "Upgrade of <babysitter> was successful"
exit 0
}


upgrade_for_solaris()
{

echo "Upgrading babysitter..................."
echo "Checking dependencies..........."

core_kit="/usr/tmp/Babysitter_4.1.1.3_Build01"
upgrade_kit="/usr/tmp/UPG-KIT-BABYSITTER-4.1.1.3-01"

 if [ ! -f $core_kit ]; then
     echo "error: open of $core_kit failed: No such file or directory"
      echo "babysitter kit  not added -  installation failed"
       echo "Upgradation of <babysitter> cannot be done....... EXITING"
       exit 1
 fi

   if [ ! -f $upgrade_kit ]; then
     echo "error: open of $upgrade_kit failed: No such file or directory"
      echo "Upgrade kit of BABYSITTER is not added -  installation failed"
       echo "Upgradation of <babysitter> cannot be done....... EXITING"
       exit 1
 fi

  if [ ! -f /usr/tmp/admin ]; then
     echo "error: open of admin failed: No such file or directory"
      echo "admin file is not added -  installation failed"
       echo "Upgradation of <babysitter> cannot be done....... EXITING"
       exit 1
 fi


 # name of the answer file for upgradation
answer_file_name="/usr/tmp/bs_answer_file"
# Variable to hold the java executable path
java_executable=''
if [ ! -f $answer_file_name ];
then
        echo "bs_answer_file not found in the /usr/tmp, Aborting upgradation......"
        exit 1
fi

# Pick the Java path from answer file.
java_executable=`cat $answer_file_name | grep '^JAVA_PATH=' | head -1 | awk -F= '{print $2}' | tr -d '\t [:space:]'`
if [ ! -f "$java_executable" ]; then
        echo "No Java runtime found. Aborting upgradation....."
        echo "Reconfigure the JAVA_PATH correctly in the bs_answer_file and try again....."
        exit 1
fi

java_ver_file="/usr/tmp/java.ver"
$java_executable -version 2> $java_ver_file
if [ $? -ne 0 ]; then
   echo "No Java runtime found. Aborting upgradation....."
   echo "Reconfigure the JAVA_PATH correctly in the bs_answer_file and try again....."
   exit 1
fi
java_installed=`cat $java_ver_file | head -1 |cut -d '"' -f2 | cut -d "." -f1-2`
rm -rf $java_ver_file

if [ "$java_installed" = "" ];
then
   echo "No Java runtime found. Aborting upgradation....."
   echo "Reconfigure the JAVA_PATH correctly in the bs_answer_file and try again....."
   exit 1
fi

java_required=1.5
if [ "$java_installed" = "1.5"  ] || [ "$java_installed" = "1.6" ] || [ "$java_installed" = "1.7" ] ; then
	echo "Installed version of Java is Java $java_installed\n"
else
	echo "Babysitter-4.1.1.3 requires java version 1.5 or later. Aborting upgradation.....\n"
	echo "Reconfigure the JAVA_PATH correctly and try again....."
     exit 1
fi

if [ "$java_executable" != "/usr/local/java/bin/java" ];
then
	# Set JRE_HOME
	jre_home=`echo "$java_executable" | awk -F"bin/java" '{print $1}'`
	# Link the specified Java to /usr/local/java
	rm -f  /usr/local/java
	ln -sf $jre_home /usr/local/java
	if [ ! -f "/usr/local/java/bin/java" ]; then
        	echo "Unable to create link /usr/local/java. Aborting upgradation....."
		exit 1
	fi
fi

pkginfo -l | grep -i UPG-KIT-BABYSITTER
if [ $? -eq 0 ]; then
    echo "Upgrade rpm of Babysitter is already installed. Uninstalling it..."
    pkgrm -n -a /usr/tmp/admin  UPG-KIT-BABYSITTER
    if [ $? -ne 0 ]; then
	    echo "Problem in uninstalling UPG-KIT-BABYSITTER. Exiting..."
	    exit 1
	fi
    echo "UPG-KIT-BABYSITTER uninstalled successfully"
fi

pkginfo -l | grep -i Babysitter
if [ $? -ne 0 ]; then
 if [ -d /usr/cti/babysitter ] || [ -d /usr/cti/apps/babysitter ] ; then
       echo "Babysitter was installed with Octopus(Unziping .gz file)"
elif [ $? -ne 0 ]; then
     echo "BABYSITTER package not installed"
     echo "Upgradation of <Babysitter> cannot be done....... EXITING"
     exit 1
fi
fi

echo "Installing Upgrade package of BABYSITTER...."
pkgadd -a admin -d $upgrade_kit UPG-KIT-BABYSITTER
if [ $? -ne 0 ]; then
    echo "Upgrade package of BABYSITTER not added - pkgadd failed"
    exit 1
fi

echo "Log details written to /usr/cti/merge/babysitter/log/babysitter_upgrade.log"
/usr/cti/merge/babysitter/merge_utility/bin/copyToTarget.sh
/usr/cti/merge/babysitter/merge_utility/bin/merge.sh
if [ $? -ne 0 ]; then
    echo "Unable to perform merge /usr/cti/merge/babysitter/merge_utility/bin/merge.sh failed"
    exit 1
fi

echo "Removing old BABYSITTER package..........."
var=`pkginfo -l Babysitter | grep -i VERSION | awk '{print $2,$3,$4}'`

if [ "$var" = "4.0.0.0 Build 02" ] || [ "$var" = "4.0.0.0 Build 03" ] || [  "$var" = "4.0.0.0 Build 04" ] ||
[ "$var" = "4.0.0.0 Build 01" ]; then

mkdir /usr/cti/conf/backuptmp
chmod 755 /usr/cti/conf/backuptmp
mv /usr/cti/conf/babysitter/* /usr/cti/conf/backuptmp/
if [ -f /usr/cti/conf/backuptmp/ApplicationsBabysitter.xml ]; then
 rm -rf /usr/cti/conf/backuptmp/ApplicationsBabysitter.xml
fi
 if [ -f /usr/cti/conf/backuptmp/ApplicationsBabysitter.scm ]; then
 rm -rf /usr/cti/conf/backuptmp/ApplicationsBabysitter.scm
fi
if [ -f /usr/cti/conf/backuptmp/ApplicationsBabysitter.xsd ]; then
 rm -rf /usr/cti/conf/backuptmp/ApplicationsBabysitter.xsd
fi
if [ -f /usr/cti/conf/backuptmp/Babysitter.ini ]; then
 rm -rf /usr/cti/conf/backuptmp/Babysitter.ini
fi
if [ -f /usr/cti/conf/backuptmp/Babysitter.scm ]; then
 rm -rf /usr/cti/conf/backuptmp/Babysitter.scm
fi
if [ -f /usr/cti/conf/backuptmp/Babysitter.xsd ]; then
 rm -rf /usr/cti/conf/backuptmp/Babysitter.xsd
fi

if [ -f /usr/cti/conf/backuptmp/log4j.properties ]; then
 rm -rf /usr/cti/conf/backuptmp/log4j.properties
fi

if [ -f /usr/cti/conf/backuptmp/nfo_Babysitter ]; then
 rm -rf /usr/cti/conf/backuptmp/info_Babysitter
fi
if [ -d /usr/cti/conf/backuptmp/kfiles ]; then
 rm -rf /usr/cti/conf/backuptmp/kfiles
fi

fi
pkgrm -n -a admin  Babysitter
 if [ $? -ne 0 ]; then
    echo "Package BABYSITTER not removed - pkgrm failed"
    exit 1
fi
# change Add By Rahul which suggest by Brajendra
Babwatchpid=`ps -ef| grep -v grep | grep -v babysitter.jar |grep -i babwatch.jar | awk '{print $2}' | xargs`
if [ -n "$Babwatchpid" ]
then
kill -9 $Babwatchpid
fi

Babypid=`ps -ef| grep -v grep | grep -v babwatch.jar |grep -i babysitter.jar | awk '{print $2}' | xargs`
if [ -n "$Babypid" ]
then
kill -9 $Babypid
fi
# change end By Rahul which suggest by Brajendra

echo "Installing new Babysitter package.........."
pkgadd -a admin -d $core_kit Babysitter
if [ $? -ne 0 ]; then
    echo "Package BABYSITTER not added - pkgadd failed"
    exit 1
fi

/usr/cti/merge/babysitter/merge_utility/bin/copyToSource.sh
if [ -d /usr/cti/conf/backuptmp ]; then
mv  /usr/cti/conf/backuptmp/* /usr/cti/conf/babysitter/
fi
#chmod 640 /usr/cti/conf/babysitter/*
# chmod 700 /usr/cti/conf/babysitter/kfiles
if [ -d /usr/cti/conf/backuptmp ];then
rm -rf /usr/cti/conf/backuptmp
fi

#pick the value of StartOnEnd from answer file
start_bs=`cat $answer_file_name | grep '^StartOnEnd=' | head -1 | awk -F= '{print $2}' | tr -d '\t [:space:]' | tr '[:upper:]' '[:lower:]'`
if [ "$start_bs" != "false" ]; then
    /etc/init.d/babysitter start
fi

echo "Upgrade of <BABYSITTER> was successful"
exit 0

}
## MAIN ##
Type=`uname`
echo "OSType:${Type}"
OSType=`echo $Type | tr '[a-z]' '[A-Z]'`
if [ "$OSType" = "LINUX" ]; then
upgrade_for_linux
else
upgrade_for_solaris
fi
