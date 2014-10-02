#!/bin/sh

#if [ $# -ne 2 ]
#then
#	echo "Missing Parameters."
#	echo "Usage:   $0 <Version Number> <Build Number>"
#	echo ""
#	exit 1
#fi

#VERSION=$1
#BUILD=$2

VERSION=1.0.0.0
BUILD=01

## VIEWDIR=`pwd | perl -p -e 's/\/[^\/]+?$//'`
VIEWDIR=`pwd`

rpmbuild -bb -v -D "ViewDir $VIEWDIR" 	\
	-D '_rpm_name FirstLook_IS4' 	\
	-D "_rpm_version $VERSION" 	\
	-D "_rpm_stf $BUILD" 		\
	FirstLook.spec
