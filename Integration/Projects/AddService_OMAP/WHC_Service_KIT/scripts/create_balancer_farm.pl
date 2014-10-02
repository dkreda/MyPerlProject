#!/usr/bin/perl

use strict;
use warnings;

if ($#ARGV ne 5)
{
        print "Usage: $0 <Balancer farm to create> <IP list comma separated> <Greeting 0/1> <Ping 0/1> <Port> <Port2>\n";
        exit(1);
}

my $farmToCreate=shift;
my $ipListString=shift;
my $greeting=shift;
my $ping=shift;
my $port=shift;
my $port2=shift;

my $file="/usr/cti/conf/balancer/balancer.conf";

my @ipList=split(/,/,$ipListString);
if ($ipList[0]=~/none/i) {
	print "Warning:  \"None\" specified, not creating $farmToCreate farm";
	exit(0);
}

open BALANCER, ">> $file" or die "Cannot open $file for appending\n";
print BALANCER ("\n");
print BALANCER ("[farm=$farmToCreate]\n");
my $serverNumber=1;
foreach my $ip(@ipList) {
	print BALANCER ("server$serverNumber=$ip,A,\n");
	$serverNumber++;
}
print BALANCER ("greeting=$greeting\n");
print BALANCER ("ping=$ping\n");
print BALANCER ("port=$port\n");
print BALANCER ("port2=$port2\n");
close BALANCER;
