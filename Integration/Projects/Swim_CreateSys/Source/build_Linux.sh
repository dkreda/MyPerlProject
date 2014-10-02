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
### Setting version to CAF ....
if [ ! -e Linux/createSystem-CAF.xml ]
then echo "Error: file Linux/createSystem-CAF.xml Not exists or the build scripts run from the wrong directory ..."
exit 1
fi

VIEWDIR=`pwd | perl -p -e 's/\/[^\/]+?$//'`
perl -pi -e "BEGIN { \$Release=\"$VERSION-$BUILD\" }" -e '/Component/ and s/(Version=)".+?"/$1"$Release"/' Linux/createSystem-CAF.xml
rpmbuild -bb -v -D "ViewDir $VIEWDIR" 	\
	-D '_rpm_name SwimInteg' 	\
	-D "_rpm_version $VERSION" 	\
	-D "_rpm_stf $BUILD" 		\
	SwimCreateSys.spec
