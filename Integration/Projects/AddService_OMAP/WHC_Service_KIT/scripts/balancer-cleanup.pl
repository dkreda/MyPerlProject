#!/usr/bin/perl
$file="/usr/cti/conf/balancer/balancer.conf";
`cp -pf $file $file.backup`;

open BALANCER, "< $file" or die "Cannot open $file for reading\n";
my @newfile="";
my @buffer="";
my $in_farm;
while (<BALANCER>) {
        chomp($line=$_);
        if (!($line=~/^\[farm=\S+\]/) && !($in_farm)) {
                push(@newfile,$_);
        } elsif ($line=~/^\[farm=\S+\]/ && !($in_farm)) {
                $in_farm=1;
                push(@buffer,$_);
        } elsif ($line=~/^\[farm=\S+\]/ && $in_farm) {
                foreach my $line(@buffer) {
                        if ($line=~/^[Ss]erver/ && !($line=~/^server\d+=none/i)) {
                                push(@newfile,@buffer);
                                last;
                        }
                }
                @buffer="";
                push(@buffer,$_);
        } elsif ($in_farm) {
                push(@buffer,$_);
        }
}

#This will test the last farm
foreach my $line(@buffer) {
        if ($line=~/^[Ss]erver/ && !($line=~/^server\d+=none/i)) {
                push(@newfile,@buffer);
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
