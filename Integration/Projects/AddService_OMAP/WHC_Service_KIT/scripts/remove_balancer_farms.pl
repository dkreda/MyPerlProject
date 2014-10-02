#!/usr/bin/perl

use strict;
use warnings;

if ($#ARGV ne 0)
{
        print "Usage: $0 <Balancer farm to remove>\n";
        exit(1);
}

my $farmToRemove=shift;

my $file="/usr/cti/conf/balancer/balancer.conf";

open BALANCER, "< $file" or die "Cannot open $file for reading\n";
my @newfile="";
my @buffer="";
my $in_farm;
my $line;
while (<BALANCER>)
{
        chomp($line=$_);
        if (!($line=~/^\[farm=\S+\]/) && !($in_farm))
        {
                push(@newfile,$_);
        }
        elsif ($line=~/^\[farm=\S+\]/ && !($in_farm))
        {
                $in_farm=1;
                push(@buffer,$_);
        }
        elsif ($line=~/^\[farm=\S+\]/ && $in_farm)
        {
                foreach my $line(@buffer)
                {
                        if ($line=~/farm/i && !($line=~/^\[farm=(\S*$farmToRemove\S*)\]$/i))
                        {
                                push(@newfile,@buffer);
                                last;
                        }
                        elsif ($line=~/^\[farm=(\S*$farmToRemove\S*)\]$/i)
                        {
                                my $farmName=$1;
                                print "Removing balancer farm $farmName\n";
                                last;
                        }
                }
                @buffer="";
                push(@buffer,$_);
        }
        elsif ($in_farm)
        {
                push(@buffer,$_);
        }
}

#This will test the last farm
foreach my $line(@buffer)
{
        if ($line=~/farm/i && !($line=~/^\[farm=(\S*$farmToRemove\S*)\]$/i))
        {
                push(@newfile,@buffer);
                last;
        }
        elsif ($line=~/^\[farm=(\S*$farmToRemove\S*)\]$/i)
		{
                	my $farmName=$1;
			print "Removing balancer farm $farmName\n";
			last;
		}
}

close BALANCER;

open BALANCER, "> $file" or die "Cannot open $file for appending\n";
foreach $line(@newfile)
{
        print BALANCER "$line";
}
close BALANCER;
