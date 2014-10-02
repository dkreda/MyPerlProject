#!/bin/sh

if [ $# -ne 2 ]
then
	echo "Missing Parameters."
	echo "Usage:   $0 <Version Number> <Build Number>"
	echo ""
	exit 1
fi

VERSION=$1
BUILD=$2

SPEC=Demo.spec
		

VIEWDIR=`pwd`

rpmbuild -bb -v -D "ViewDir $VIEWDIR" 	\
	-D '_rpm_name SWIMDemo'	\
	-D "_rpm_version $VERSION" 	\
	-D "_rpm_stf $BUILD" 		\
	-D "stf $BUILD" 		\
	-D 'product SWIMDemo'	\
	-D "version $VERSION" 	\
	$SPEC



