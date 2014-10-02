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

if [ ! -f Common/createSystem-CAF.xml ]
then echo "Error: file Common/createSystem-CAF.xml Not exists or the build scripts run from the wrong directory ..."
exit 1
fi

PKGNAME=`perl -n -e '/PKG/ and s/^.+=// and print $_' Solaris/pkginfo`
PKGNAME="$PKGNAME-$VERSION-$BUILD"

echo Update createSystem-CAF.xml ...
perl -pi -e '/Component/ and s/(Version=)".+?"/$1"$ARGV[0]"/ and s/(Platform=)".+?"/$1"SunOS"/' Common/createSystem-CAF.xml "$VERSION-$BUILD"
echo Update SwimManager-UAF.xml ...
perl -pi -e '/UnitType/ and s/(Platform=)".+?"/$1"SunOS"/' Common/SwimManager-UAF.xml
echo Update BuildSwimSystem.pl ...
perl -pi -e '$. == 1 and $_="#!/usr/local/bin/perl\n"' Common/BuildSwimSystem.pl

## perl -pi -e "BEGIN { \$Release=\"$VERSION-$BUILD\" }" -e '/Component/ and s/(Version=)".+?"/$1"$Release"/' Solaris/createSystem-CAF.xml
mkdir -p PKG/TmpDir
pkgmk -v "$VERSION-$BUILD" -d ./PKG/TmpDir -o -r . -f ./Solaris/prototype
touch ./PKG/$PKGNAME.pkg
pkgtrans -s ./PKG/TmpDir ./PKG/$PKGNAME.pkg all
if [ "$?" -eq "0" ] 
then echo  "removing temporary files ..."
rm -rf ./PKG/TmpDir
fi
