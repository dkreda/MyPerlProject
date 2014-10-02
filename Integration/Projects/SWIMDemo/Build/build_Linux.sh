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

SPEC=`uname -a | perl -n -e '%MapSpec=( el5  => "WHCProfileDefinition_Rel5.spec" , 
		el6	=> "WHCProfileDefinition_Rel6.spec" ) ; /\.(el\d+)/ and print "$MapSpec{$1}\n"'`
		

### Setting version to CAF ....
if [ -e ./Install/ProfileDefinition_WHC-CAF.xml ]
then perl -pi -e '/Component/ and s/(Version=)".+?"/$1"$ARGV[0]"/' Install/ProfileDefinition_WHC-CAF.xml "$VERSION-$BUILD"
fi

VIEWDIR=`pwd | perl -p -e 's/\/[^\/]+?$//'`

rpmbuild -bb -v -D "ViewDir $VIEWDIR" 	\
	-D '_rpm_name ProfileDefinition_WHC'	\
	-D "_rpm_version $VERSION" 	\
	-D "_rpm_stf $BUILD" 		\
	-D "stf $BUILD" 		\
	-D 'product ProfileDefinition_WHC'	\
	-D "version $VERSION" 	\
	$SPEC



