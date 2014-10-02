#!/usr/bin/perl
$file="/usr/cti/conf/alc/ALC_conf.xml";
$param="File_Format";
$oldValue="None";
$newValue="IS4";
`cp -pf $file $file.backup`;

open PARAM, "< $file" or die "Cannot open $file for reading\n";
my @newfile="";
my @buffer="";
while (<PARAM>) {
	$line=$_;
	if ($line=~/$param/) {
		$line=~s/$oldValue/$newValue/;
		push(@newfile,$line);
	} else {
		push(@newfile,$line);
	}
}
close PARAM;

open PARAM, "> $file" or die "Cannot open $file for appending\n";
foreach $line(@newfile) {
	print PARAM "$line";
}
close PARAM;
