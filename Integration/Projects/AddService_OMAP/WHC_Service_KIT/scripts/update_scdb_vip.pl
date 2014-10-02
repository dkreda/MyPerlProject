#!/usr/bin/perl
use strict;
use warnings;

if($#ARGV ne 4)
{
   print "Usage: $0 <InSight4|StandAlone> <ApplicationName> <IP Address> <Unit Type> <System Name>\n";
   exit(1);
}

my $platName=shift;
my $appName=shift;
my $vip=shift;
my $unitType=shift;
my $sysName=shift;

if ($platName eq "StandAlone") {

        my @results1=`su - scdb_user -c \"\/usr\/cti\/scdb\/bin\/scdbCli.sh delete Application System=\'$sysName\' Object=\'sys100_\'$unitType\'_Unit\' ApplicationName=\'$appName\'\" > /dev/null`;
        my @results2=`su - scdb_user -c \"/usr/cti/scdb/bin/scdbCli.sh add Application System=\'$sysName\' Object=\'sys100_\'$unitType\'_Unit\' ApplicationLabel=\'$appName\' ApplicationLevel=\'N/A\' ApplicationName=\'$appName\' ConnectionType=\'Virtual\' VirtualIp=\'$vip\'\"`;
        if ($?) {
                print "Failed to assign $vip to $appName under $sysName for $platName:\n@results2";
                exit(1);
        } else {
                print "@results2 \n";
        }
}

elsif ($platName eq "InSight4") {

        my @results1=`su - scdb_user -c \"\/usr\/cti\/scdb\/bin\/scdbCli.sh delete Application System=\'$sysName\' Object=$unitType\'_Unit\' ApplicationName=\'$appName\'\" > /dev/null`;
        my @results2=`su - scdb_user -c \"/usr/cti/scdb/bin/scdbCli.sh add Application System=\'$sysName\' Object=$unitType\'_Unit\' ApplicationLabel=\'$appName\' ApplicationLevel=\'N/A\' ApplicationName=\'$appName\' ConnectionType=\'Virtual\' VirtualIp=\'$vip\'\"`;
        if ($?) {
                print "Failed to assign $vip to $appName under $sysName for $platName:\n@results2";
                exit(1);
        } else {
                print "@results2 \n";
        }
}