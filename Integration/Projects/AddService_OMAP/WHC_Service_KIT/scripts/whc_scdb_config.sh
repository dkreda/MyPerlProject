#!/bin/sh

if [ $# -ne 3 ]
then
        echo "Missing parameters:"
        echo "Usage:    $0 <InSight4|StandAlone> <System Name> <TCM Enabled>"
        exit 1
fi

PLATFORM=$1
SYS_NAME=$2
TCM_ENABLED=$3

case $PLATFORM in 
  "InSight4")
	su - scdb_user -c "/usr/cti/scdb/bin/scdbCli.sh delete Application System='$SYS_NAME' Object='NDU-WHC_Unit' ApplicationName='NDSVAN.SITE1'" > /dev/null
        su - scdb_user -c "/usr/cti/scdb/bin/scdbCli.sh add Application System='$SYS_NAME' Object='NDU-WHC_Unit' ApplicationLabel='NDSVAN.SITE1' ApplicationLevel='Farm' ApplicationName='NDSVAN.SITE1' ConnectionType='Data' FQDNConcat='true'"
        if [ "$?" != "0" ]
        then
               echo "Error adding NDSVAN.SITE1 farm to SCDB"
               exit 1
	fi
        ;;
  "StandAlone")

        cp /var/tmp/whc_service/registrations.xml /usr/cti/conf/scdb/registrations.xml
        if [ -d /opt/CMVT/scdb/data ]
        then
                cp /var/tmp/whc_service/scdb.xml /opt/CMVT/scdb/data/scdb.xml
        fi

	if [ "$TCM_ENABLED" = "Yes" ]
	then
		su - scdb_user -c "/usr/cti/scdb/bin/scdbCli.sh delete Application System='$SYS_NAME' Object='sys100_OMU_Unit' ApplicationName='TCMMANAGER'" > /dev/null
		su - scdb_user -c "/usr/cti/scdb/bin/scdbCli.sh delete Application System='$SYS_NAME' Object='sys100_OMU_Unit' ApplicationName='TCMSERVER'" > /dev/null
		
		su - scdb_user -c "/usr/cti/scdb/bin/scdbCli.sh add Application System='$SYS_NAME' Object='sys100_OMU_Unit' ApplicationLabel='TCMMANAGER' ApplicationLevel='Unit' ApplicationName='TCMMANAGER' ConnectionType='Data' ConnectionType='Data' HostingUnits=''"
	        if [ "$?" != "0" ]
		then
			echo "Error adding TCMMANAGER unit to SCDB"
		fi

		su - scdb_user -c "/usr/cti/scdb/bin/scdbCli.sh add Application System='$SYS_NAME' Object='sys100_OMU_Unit' ApplicationLabel='TCMSERVER' ApplicationLevel='Farm' ApplicationName='TCMSERVER' ConnectionType='Data' ConnectionType='Data'"
	        if [ "$?" != "0" ]
		then
			echo "Error adding TCMSERVER farm to SCDB"
		fi
	fi

        ;;
    *)  echo "Usage:    $0 <InSight4|StandAlone> <System Name> <TCM Enabled>";
        exit 1
        ;;	
esac