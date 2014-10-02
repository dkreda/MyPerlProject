#!/usr/bin/perl

my $IP=`hostname -i` ;
open FILE, "< /etc/named.conf" or die "Error - Fail to open /etc/named.conf\n";
my @Cont=<FILE>;
close FILE ;
chomp @Cont;
chomp $IP;
my @Lines=grep(/forwarders/,@Cont);
chomp @Lines;
foreach my $Iter (@Lines)
{
	$Iter =~ /\D$IP\D/ and die "Yes\n";
}
print "No\n";
