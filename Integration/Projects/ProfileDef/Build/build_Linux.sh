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

SPEC=`uname -a | perl -n -e '%MapSpec=( el5  => "RpmForLinux5.spec" , 
		el6	=> "RpmSpecForL6" ) ; /\.(el\d+)/ and print "$MapSpec{$1}\n"'`
		
exit 0
### Setting version to CAF ....
if [ ! -e Common/createSystem-CAF.xml ]
then echo "Error: file Linux/createSystem-CAF.xml Not exists or the build scripts run from the wrong directory ..."
exit 1
fi

VIEWDIR=`pwd | perl -p -e 's/\/[^\/]+?$//'`

echo Update createSystem-CAF.xml ...
perl -pi -e '/Component/ and s/(Version=)".+?"/$1"$ARGV[0]"/ and s/(Platform=)".+?"/$1"Linux"/' Common/createSystem-CAF.xml "$VERSION-$BUILD"
echo Update SwimManager-UAF.xml ...
perl -pi -e '/UnitType/ and s/(Platform=)".+?"/$1"Linux"/' Common/SwimManager-UAF.xml
echo Update BuildSwimSystem.pl ...
perl -pi -e '$. == 1 and $_="#!/usr/cti/apps/CSPbase/Perl/bin/perl\n"' Common/BuildSwimSystem.pl

## perl -pi -e "BEGIN { \$Release=\"$VERSION-$BUILD\" }" -e '/Component/ and s/(Version=)".+?"/$1"$Release"/' Linux/createSystem-CAF.xml


rpmbuild -bb -v -D "ViewDir $VIEWDIR" 	\
	-D '_rpm_name ProfileDefinition_WHC'	\
	-D "_rpm_version $VERSION" 	\
	-D "_rpm_stf $BUILD" 		\
	Linux/SwimCreateSys.spec



