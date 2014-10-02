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

SPEC=`uname -a | perl -n -e '%MapSpec=( el5  => "VIProfileDefinition_Rel5.spec" , 
		el6	=> "VIProfileDefinition_Rel6.spec" ) ; /\.(el\d+)/ and print "$MapSpec{$1}\n"'`
		

### Setting version to CAF ....
if [ -e ./Install/ProfileDefinition_VI-CAF.xml ]
then perl -pi -e '/Component/ and s/(Version=)".+?"/$1"$ARGV[0]"/' Install/ProfileDefinition_VI-CAF.xml "$VERSION-$BUILD"
fi

VIEWDIR=`pwd | perl -p -e 's/\/[^\/]+?$//'`

rpmbuild -bb -v -D "ViewDir $VIEWDIR" 	\
	-D '_rpm_name ProfileDefinition_VI'	\
	-D "_rpm_version $VERSION" 	\
	-D "_rpm_stf $BUILD" 		\
	-D "stf $BUILD" 		\
	-D 'product ProfileDefinition_VI'	\
	-D "version $VERSION" 	\
	$SPEC



