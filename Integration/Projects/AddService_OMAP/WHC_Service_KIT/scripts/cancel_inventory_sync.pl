#!/usr/bin/perl
$file="/usr/cti/conf/scdb/scdb/parameters.xml";
$param="AutomaticInventorySync";
$oldValue="Item Value='\\w*'";
$newValue="Item Value='false'";
`cp -pf $file $file.backup`;

open PARAM, "< $file" or die "Cannot open $file for reading\n";
my @newfile="";
my @buffer="";
my $found_param=0;
while (<PARAM>) {
	$line=$_;
        if (!($line=~/$param/) && !($found_param)) {
                push(@newfile,$line);
        } elsif ($line=~/$param/ && !($found_param)) {
                $found_param=1;
                push(@newfile,$line);
        } elsif ($line=~/$oldValue/ && $found_param) {
                $line=~s/$oldValue/$newValue/;
                push(@newfile,$line);
                $found_param=0;
        } elsif ($found_param) {
                push(@newfile,$line);
        }
}
close PARAM;

open PARAM, "> $file" or die "Cannot open $file for appending\n";
foreach $line(@newfile) {
        print PARAM "$line";
}
close PARAM;
