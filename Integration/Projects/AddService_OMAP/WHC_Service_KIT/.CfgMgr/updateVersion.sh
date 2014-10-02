#!/bin/sh

# Update CAF Version

if [ $# -lt 3 ]
then
	echo "Missing Parameters."
	echo "Usage:   $0 <CAF File name> <Version> <Build>"
	echo ""
	exit 1
fi

CAFFile=$1
Release="$2-$3"

if [ ! -f $CAFFile ]
then
	echo "Can not find CAF File $CAFFile"
	echo "Current Directory:" `pwd`
	exit 1
fi

perl -pi -e '/Component/ and s/(Version=)".+?"/$1"$ARGV[-1]"/' $CAFFile "$Release"