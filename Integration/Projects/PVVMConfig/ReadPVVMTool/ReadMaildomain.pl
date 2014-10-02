#!/usr/bin/perl

use strict;

my $G_mgrPath="/opt/criticalpath/global/bin";
my $G_MipsPassword="A25Trk7B43";

sub IsDomainOK # domain, [server ip]
{
    my $Domain=shift;
    my $Server=shift;
    my $Cmd="$G_mgrPath/mgr " . ($Server ne "" ? "-s $Server " : "" ) . "-w $G_MipsPassword domain SHOW $Domain" ;
    my @Params=`$Cmd 2>&1`;
    my ($Iter);
    
    foreach $Iter (@Params)
    {
    	if ( $Iter =~ /CLASS|SWITCH/ )
    	{
    	    return 1;
    	}
    }
    return 0;
}

sub getDomains #[ MipsIP ]
{
   my $Server=shift;
   my $Cmd="$G_mgrPath/mgr " . ($Server ne "" ? "-s $Server " : "" ) . "-w $G_MipsPassword domain list" ;
   my @Answer=`$Cmd 2>&1`;
   my @Domains=();
   my $Iter;
   
   foreach $Iter (@Answer)
   {
   	chomp $Iter;
   	## print "Check domain $Iter\n";
   	if ( $Iter =~ /([^*\s]+)/ )
   	{
   	     $Iter=$1;
   	     if ( IsDomainOK($Iter,$Server) )
   	     {
   	     	push (@Domains,$1);
   	     }
   	}
   }
   return @Domains;
}


foreach (getDomains("10.106.50.13"))
{
    print "$_\n";
}