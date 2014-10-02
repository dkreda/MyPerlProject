#!/bin/sh

if [ $# -ne 2 ]
then
        echo "Missing parameters:"
        echo "Usage:    $0 <enable|disable> <Name of XML file>"
        echo "Example:  $0 enable ApplicationsXYZ.xml"
        exit 1
fi

# Variable definitions
function=$1
xml_path=/usr/cti/conf/babysitter
xml_file=$2
extension=service_kit

if [ $function == "enable" ]
then
	if [ -f $xml_path/$xml_file ]
	then
		echo $xml_file already exists
		exit 0
	fi
	if [ -f $xml_path/$xml_file.$extension ]
	then
		echo Renaming $xml_file.$extension to $xml_file
		\mv $xml_path/$xml_file.$extension $xml_path/$xml_file
		exit 0
	else
		echo Unable to enable $xml_file:
		echo $xml_path/$xml_file.$extension does not exist
		exit 1
	fi
fi

if [ $function == "disable" ]
then
	if [ -f $xml_path/$xml_file ]
	then
		echo Renaming $xml_file to $xml_file.$extension
		\mv $xml_path/$xml_file $xml_path/$xml_file.$extension
		exit 0
	else
		echo $xml_path/$xml_file does not exist
		# This should not cause an error because the net result is what we want
		exit 0
	fi
	if [ -f $xml_path/$xml_file.$extension ]
	then
		echo $xml_file.$extension already exists
		exit 0
	fi
fi
