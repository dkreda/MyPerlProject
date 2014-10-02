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

if [ ! -e Solaris/createSystem-CAF.xml ]
then echo "Error: file Solaris/createSystem-CAF.xml Not exists or the build scripts run from the wrong directory ..."
exit 1
fi
perl -pi -e "BEGIN { \$Release=\"$VERSION-$BUILD\" }" -e '/Component/ and s/(Version=)".+?"/$1"$Release"/' Solaris/createSystem-CAF.xml
mkdir -p PKG/TmpDir
pkgmk -v "$VERSION-$BUILD" -d ./PKG/TmpDir -o -r . -f ./prototype
touch ./PKG/SWIM-APP-CreateSystem.pkg
pkgtrans -s ./PKG/TmpDir ./PKG/SWIM-APP-CreateSystem.pkg all
if [ "$?" -eq "0" ] 
then echo  "removing temporary files ..."
rm -rf ./PKG/TmpDir
fi
