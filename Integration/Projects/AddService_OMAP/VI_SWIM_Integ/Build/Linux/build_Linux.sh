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
if [ ! -e Common/createSystem-CAF.xml ]
then echo "Error: file Linux/createSystem-CAF.xml Not exists or the build scripts run from the wrong directory ..."
exit 1
fi

VIEWDIR=`pwd | perl -p -e 's/\/[^\/]+?$//'`

echo Update createSystem-CAF.xml ...
perl -pi -e '/Component/ and s/(Version=)".+?"/$1"$ARGV[-1]"/ and s/(Platform=)".+?"/$1"Linux"/' Common/createSystem-CAF.xml AddService/createSystem-CAF.xml "$VERSION-$BUILD"
echo Update SwimManager-UAF.xml ...
perl -pi -e '/UnitType/ and s/(Platform=)".+?"/$1"Linux"/' Common/SwimManager-UAF.xml
echo Update BuildSwimSystem.pl ...
perl -pi -e '$. == 1 and $_="#!/usr/cti/apps/CSPbase/Perl/bin/perl\n"' Common/BuildSwimSystem.pl

echo > ~/.rpmmacros

rpmbuild -bb -v -D "ViewDir $VIEWDIR" 	\
	-D '_PrivateTest SwimInteg' 	\
	-D "_rpm_version $VERSION" 	\
	-D "_rpm_stf $BUILD" 		\
	Linux/SwimCreateSys.spec
