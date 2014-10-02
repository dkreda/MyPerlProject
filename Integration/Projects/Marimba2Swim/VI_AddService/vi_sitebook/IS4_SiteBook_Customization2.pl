#!/usr/bin/perl

###############################################################
#This script is customizing the sitebook                      #
###############################################################
#Author: Rami Nachum                                          #
#Date: 14/09/09                                               #
#Updated at 27/10/09 by: Lior Yosef                           #
#################################################################################
#USAGE: SiteBook_Customization.pl <System Domain Name (e.g sys100> <metadafile> #
#################################################################################

##################################################################################################
# TIRS                                                                                           #
# TIR PSG00545222 - Site Book, incorrect automatic scaning start time	Minor	Waiting4Solution #
##################################################################################################


use strict;
use warnings;

if (! $ARGV[1]) {
	print "Missing Parameters.\n";
	print "Usage:   $0 {System Domain Name}\n";
	print "\n";
	exit 1;
}

my $sysName=shift;
my $metaDataFile=shift;
my $logFile = "/var/cti/logs/whc_sitebook/sitebook_customization.log";
my $logDir = "/var/cti/logs/whc_sitebook";
my $unitGroupPath = "/opt/CMVT/scdb/data/UnitGroups/" . $sysName . "/UnitGroup.xml";
my @array_List_Of_MetaDataFiles;
my $pointer_List_Of_MetaDataFiles = \@array_List_Of_MetaDataFiles;
my $metaDataFiles_Dir = "/usr/cti/conf/sitebook";
my $metaDataFiles_Pattern = 'sitebook_md_*.xml';
my @tmp_Parse;
my $unit_Group;
my $meta_Data_File;
my $sitebook_cli;

#Opening the log file
if(!-d "/var/cti/logs/whc_sitebook")
{
  mkdir($logDir, 0777);
}
open (LOGFILE, ">", $logFile) or do
{
	print("Failed to create logfile: $logFile : $! Abort!\n");
	exit(2);
};

#Define the CLI path
if(-d "/usr/cti/apps/sitebook")
{
	$sitebook_cli = "/usr/cti/apps/sitebook/catalinaBase/webapps/sitebook/SiteBook_CLI.sh";
}
else
{
	$sitebook_cli = "/usr/cti/sitebook/catalinaBase/webapps/sitebook/SiteBook_CLI.sh";
}

sub get_List_Of_MetaDataFiles($$$)
{
	my ($path, $pattern, $pointer) = @_;
	my $i=0;
	my @list;

	@list=glob("$path/$pattern");

	foreach (@list)
	{
		@tmp_Parse = split(/\//, $_);
		$pointer->[$i] = $tmp_Parse[-1];
		$i++;
	}
}

sub printScreenLog
{
	my($message,$type) = @_;
	print "$message";
	if ($type)
	{
		$type =~ tr/a-z/A-Z/; #converting the type to upper case
	}
	else
	{
		$type = "";
	}
	print LOGFILE "[$type] $message";
	if($type eq "ERROR")
	{
		close(LOGFILE);
		exit 1;
	}
}

sub runCLI
{
  my $command = $_[0];
  my $chkExitStatusFlag="";
  my $output;
  $output = `$command`;
  my $retVal = $?;

	if ($_[1])
	{
		$chkExitStatusFlag = $_[1];
	}


  if($retVal != 0)
  {
	  if ($chkExitStatusFlag eq "dont_check_exist_status")
	  {
		   printScreenLog("failed to run command:\n $command\n\n\n","WARNING");
	  }
	  else
	  {
			printScreenLog("failed to run command:\n $command\n\n\n","ERROR");
	  }
  } 
  else
  {
    printScreenLog("The command: \n $command \n- run succesfully\n\n\n","INFO");
  }

  printScreenLog("Output of command: $output\n", "INFO");
}

#Get list of meta data files
#get_List_Of_MetaDataFiles($metaDataFiles_Dir, $metaDataFiles_Pattern, $pointer_List_Of_MetaDataFiles);

#upload meta data files
printScreenLog("********* start uploading the meta data files *********\n","INFO");
#foreach (@array_List_Of_MetaDataFiles)
#{
	if(-d "/usr/cti/apps/sitebook")
	{
		runCLI("$sitebook_cli upload_metadata_file SBAdmin Sbm1Cmv4\$ $metaDataFiles_Dir/$metaDataFile");
	}
	else
	{
		runCLI("$sitebook_cli upload_metadata_file $metaDataFiles_Dir/$metaDataFile");
	}
	
#}
printScreenLog("********* finished uploading the meta data files *********\n","INFO");


#Create topology using the UnitGroup.xml file
printScreenLog("********* start creating topology file *********\n","INFO");
#runCLI("/usr/cti/sitebook/catalinaBase/webapps/sitebook/SiteBook_CLI.sh create_topology_file  SBAdmin Sbm1Cmv4\$ $unitGroupPath unitgroup IP");
	if(-d "/usr/cti/apps/sitebook")
	{
		if(-d "/opt/CMVT/scdb/data")
		{
			`cp /opt/CMVT/scdb/data/SystemList.* /usr/cti/apps/sitebook/catalinaBase/webapps/sitebook/config/`;
			`cp /opt/CMVT/scdb/data/UnitGroup.xsd /usr/cti/apps/sitebook/catalinaBase/webapps/sitebook/config/`;
			if(-d "/opt/CMVT/scdb/data/UnitGroups")
			{
				`cp -r /opt/CMVT/scdb/data/UnitGroups/$sysName /usr/cti/apps/sitebook/catalinaBase/webapps/sitebook/config/`;
			}
			else
			{
				`cp -r /opt/CMVT/scdb/data/$sysName /usr/cti/apps/sitebook/catalinaBase/webapps/sitebook/config/`;
			}
			`chmod -R 755 /usr/cti/apps/sitebook/catalinaBase/webapps/sitebook/config`;
			`chown -R sitebook:sitebook /usr/cti/apps/sitebook/catalinaBase/webapps/sitebook/config`;
		}
		runCLI("$sitebook_cli reflect_topology");
	}
	else
	{
		runCLI("$sitebook_cli create_topology_file SBAdmin Sbm1Cmv4\$ $unitGroupPath unitgroup hostname");
	}
	
printScreenLog("********* finished creating topology file *********\n","INFO");

#connect meta data to topolgy
printScreenLog("********* start connecting metadata to topology *********\n","INFO");
#foreach (@array_List_Of_MetaDataFiles)
#{
	$meta_Data_File = $metaDataFile;
	$unit_Group = $meta_Data_File;
	$unit_Group =~ s/\.xml$//;
	$unit_Group =~ s/^sitebook_md_//;

	runCLI("$sitebook_cli update_topology_metadata SBAdmin Sbm1Cmv4\$ Layer SiteTopology/Layer/".$unit_Group."_Group $meta_Data_File","dont_check_exist_status");
#}
printScreenLog("********* finished connecting metadata to topology *********\n","INFO");

#Credentials updating 
printScreenLog("********* start updating credentials *********\n","INFO");
if(-d "/usr/cti/apps/sitebook")
{
	runCLI("$sitebook_cli update_topology_credentials SBAdmin Sbm1Cmv4\$ Layer SiteTopology/Layer sbuser Sbm1Cmv4\$ sftp sbuser Sbm1Cmv4\$ ssh");
}
else
{
	runCLI("$sitebook_cli update_topology_credentials SBAdmin Sbm1Cmv4\$ Layer SiteTopology/Layer sbuser,Sbm1Cmv4\$,sftp,sbuser,Sbm1Cmv4\$,ssh");
}
printScreenLog("********* finished updating credentials *********\n","INFO");


printScreenLog("\n\n********* customization script has been ended *********\n","INFO");

close(LOGFILE);