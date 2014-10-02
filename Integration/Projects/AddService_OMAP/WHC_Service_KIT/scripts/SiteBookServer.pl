#!/usr/cti/apps/CSPbase/Perl/bin/perl

##############################################################################
# Template Script.
# for use at solaris replace the first line with:
# #!/usr/local/bin/perl
#
# for use before CSPBase Installation (at Linux) change the first line to:
# #!/usr/bin/perl
##############################################################################

use strict;
use XML::LibXML;
#########################################################
#  Global variables
#########################################################

my $G_ErrorCounter=0;
my %G_CLIParams=(  LogFile  => "-" ,
				   BinDir	=> "/usr/cti/apps/sitebook/catalinaBase/webapps/sitebook" ,
				   UnitGroup => "/tmp/UnitGroup.xml");
my @G_FileHandle=();
sub usage
{
	 print "$0 -SysName SystemName [-BinDir SiteBook Binarry Folder] [-UnitGroup Temp Unit Group that is used to check] [-LogFile FileName]\n";
     print "$0 -help\n";
}

sub WrLog 
###############################################################################
#
# Input:	@Lines
#	@Lines - List of Lines to write to Log
#
# Return:	nothing
#
# Description: Write to log files ($G_CLIParams{LogFile}) if the file is close
#		it opens the file for write.
#
###############################################################################
{
    my @Lines=@_;
    if ( $#G_FileHandle < 0 )
    {
    	my @FilesList=split(/,/,$G_CLIParams{LogFile});
    	my $Counter=1;
    	foreach my $fn (@FilesList)
    	{
    		push (@G_FileHandle,eval("\\*LOGFILE$Counter"));
    		open $G_FileHandle[-1],">> $fn" or die "Fatal Error !  Fail to open LogFile \"$fn\"" ;
    		$Counter++;
    	}
    	PrnTitle("Start $0","at " . `date`);
    }
    foreach (@Lines)
    {
    	chomp $_;
    	foreach my $fh (@G_FileHandle)
    	{
    	    print $fh "$_\n";
    	}
    }
}

sub PrnTitle
###############################################################################
#
# Input:	$Text1[$Text2 ...]
#		The text to print at the Title.
#
# Return:	Nothing
#
# Description: print Title to the LogFile.
#
###############################################################################
{
   my $TSize=70;
   my $Ch_Title="*";
   my $Border=$Ch_Title x ($TSize + 4);
   
   WrLog($Border);
   foreach (@_)
   {
       chomp $_;
       $_ =~ s/\t/  /g ;
       WrLog(sprintf ("$Ch_Title %-${TSize}s $Ch_Title\n",$_));
   }
   WrLog($Border);
}

sub EndProg
###############################################################################
#
# Input:	ExitCode[,@Lines]
#		ExitCode - integer. The exit code the program will exit.
#		@Lines - Text to print to the Log file.
#
# Return:	Nothing
#
# Description: Exit the program and close the log file.
#
###############################################################################
{
     my $ExitCode=shift;
     WrLog(@_);
     foreach my $fh (@G_FileHandle)
     {
     	defined fileno($fh) or next ;
     	close $fh ;
     }
     exit $ExitCode;
}

sub RunCmds # @list of commands
###############################################################################
#
# Input:	command1[,comand2,command3 ....]
#	    	List of command to execute.
#
# Return:	exit code of ALL commands (O.K should be 0).
#
# Description:  Execute commands. it would NOT stop by failure of single command.
#		but it will return the amount of failure ( if there were ...)
#
###############################################################################
{
    my ($Err,$Cmd);
    my $ErrCounter=0;
    my @Commands=@_;
    my @OutPut=();
    
    foreach $Cmd (@Commands)
    {
	WrLog("Execute: $Cmd");
	@OutPut=`$Cmd 2>&1`;
	$Err=$?;
	foreach (@OutPut)
	{
	    WrLog("\t$_");
	}
    	$ErrCounter += $Err;
    	if ( $Err )
    	{
    		WrLog("- Error Last Command \"$Cmd\" Finish with exit code $Err");
    	}
    }
    return $ErrCounter != 0 ? 1 : 0;
}

sub ReadFile
###############################################################################
#
# Input:	$FileName
#
# Return:	@Lines - Content of the file
#
# Description: Read the file and return the array @lines - each line is 
#		a record at the array. if an error occurred @lines will be
#		empty. and G_ErrorCounter will be increment
#
###############################################################################
{
   my $File=shift;
   my $Err=0;
   my $Line;
   my @Result=();
   unless ( -e $File )
   {
   	WrLog("ERROR - File $File does not exist!");
   	$G_ErrorCounter++;
   	return;
   }
   WrLog("Reading File $File");
   open INPUT,"< $File";
   $Err=$?;
   while ( <INPUT> )
   {
   	$Err += $?;
   	$Line=$_;
   	chomp $Line;
   	push(@Result,$Line);
   }
   close INPUT ;
   $Err += $?;
   if ( $Err )
   {
   	WrLog("ERROR - An error occured during reading the file $File.");
   	$G_ErrorCounter++;
   	return ;
   }
   return @Result;
}

sub UnitsVerification
###############################################################################
#
# Input:
#
# Return:
#
# Description:
#
###############################################################################
{
    my $UnitGroupFile=shift;
    my $CompFile=shift;
    my (%UnitGroupIpList , %SwimUnitGroupIpList);
    my ($UnitGroupHostName , $SwimUnitGroupHostName , $UnitHostname , $UnitIP);
	my $SiteBookGroup=XML::LibXML->new()->parse_file($UnitGroupFile);
	my $NewUnitsGroup=XML::LibXML->new()->parse_file($CompFile);

	#### Creating Hash Table of WHC units which appears in the UnitGroup in the following format : UnitIP -> UnitHostName
	my @UnitList=$NewUnitsGroup->findnodes("//Physical");
	my $ErrCount=0;
	foreach my $UniyGroupObj (@UnitList)
	{
		my $UnitType=$UniyGroupObj->getAttribute("GroupName");
		foreach my $UnitInstance ( $UniyGroupObj->findnodes("./UnitInstance") )
		{
			my $UHostName=$UnitInstance->getAttribute("Hostname");
			my $UIP=$UnitInstance->getAttribute("DataIp");
			my @Result=$SiteBookGroup->findnodes(qq(//Physical[\@GroupName="$UnitType"]/UnitInstance[\@DataIp="$UIP"]));
			@Result or WrLog("Error - Host $UIP is missing from system UnitGroup"), $ErrCount++ , next;
			$UHostName eq $Result[0]->getAttribute("Hostname") or WrLog("Warning - Host $UHostName ($UIP) name is differ than System HostName");
		}
	}
	return $ErrCount;
}

sub ReadCLI
###############################################################################
#
# Input:	None
#
# Return:	0 - for O.K != for Errors
#
# Description:  update the global hash %G_CLIParams with the command line params.
#	    	The command line must be at format -param val ...
#
###############################################################################
{
    my $Err=0;
    my ($ParamName,@ParamValue,$Iter);
    my @ParamMust=("SysName");
    $ParamName="";
    @ParamValue=();
    while ( $#ARGV >= 0 )
    {
    	$Iter = shift(@ARGV);
    	if ( $Iter =~ m/^-(.+)$/ )
    	{
    	    $G_CLIParams{$ParamName}=join(',',@ParamValue);
    	    $ParamName=$1;
    	    @ParamValue=();
    	    if ( $ParamName =~ /Help/i )
    	    {
    	    	usage();
    	    	EndProg();
    	    }
    	} else
    	{
    	    push(@ParamValue,$Iter);
    	}
    }
    $G_CLIParams{$ParamName}=join(',',@ParamValue);
    foreach my $Name (@ParamMust)
    {
    	defined $G_CLIParams{$Name} and next;
    	WrLog("Error - missing Parameter $Name");
    	$Err++;
    }
    return $Err;
}

############################################################################################
#
#   					M A I N
#
############################################################################################

if ( ReadCLI() )
{
    usage();
    EndProg(1);
}
my @DebugMessages=("$0 Input Parameters:");
while ( my ($PName,$PVal ) = each(%G_CLIParams) )
{
     push(@DebugMessages,sprintf("\t-%-20s = $PVal",$PName));
}
WrLog(@DebugMessages);

### Verify System Name via SystemList file  ###
my $SystemListFile="$G_CLIParams{BinDir}/config/SystemList.xml";
my $UnitGroupFile="$G_CLIParams{BinDir}/config/$G_CLIParams{SysName}/UnitGroup.xml";
-f $SystemListFile or EndProg (1,"SystemList.xml file does not exist in SiteBook Folder , please fix it using the correct CLI before Re-running the script");
-f $UnitGroupFile or EndProg (1,"$UnitGroupFile file does not exist, please fix it using the correct CLI before Re-running the script");
-f $G_CLIParams{UnitGroup} or EndProg (1,"$G_CLIParams{UnitGroup} file does not exist, please fix it using the correct CLI before Re-running the script");

my $root=XML::LibXML->new()->parse_file($SystemListFile);
my @Results=$root->findnodes("//SystemList/SystemRoot[\@SystemName=\"$G_CLIParams{SysName}\"]");
@Results or EndProg (1,"ERROR - The System Name that was entered does not appear in the SystemList.xml");
$G_ErrorCounter += UnitsVerification($UnitGroupFile,$G_CLIParams{UnitGroup});
$G_ErrorCounter or $G_ErrorCounter += RunCmds("$G_CLIParams{BinDir}/SiteBook_CLI.sh reflect_topology");
$G_ErrorCounter or $G_ErrorCounter += RunCmds("$G_CLIParams{BinDir}/SiteBook_CLI.sh rebuild_metadata" );

my $ErrMessage= $G_ErrorCounter ? "Finish with ERRORS see Log File $G_CLIParams{LogFile}" :
		"Finish Successfully :-)";
EndProg($G_ErrorCounter,$ErrMessage);