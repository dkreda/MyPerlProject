#!/usr/cti/apps/CSPbase/Perl/bin/perl

use strict;
use XML::LibXML;

#########################################################
#  Global variables
#########################################################

my %G_CLIParams=(  LogFile  => "-" );
my $G_ErrorCounter=0;
my $HostsFileName="/etc/hosts";

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
    unless ( defined fileno(LOGFILE) )
    {
         open LOGFILE,">> $G_CLIParams{LogFile}" or die "Fatal Error !  Fail to open LogFile" ;
         PrnTitle("Start $0","at " . `date`);
    }
    foreach (@Lines)
    {
    	chomp $_;
    	print LOGFILE "$_\n";
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
     if ( defined fileno(LOGFILE) )
     {
     	close LOGFILE ;
     }
     exit $ExitCode;
}

sub RunCmds # @list of commands
###############################################################################
#
# Input:	command1[,comand2,command3 ....]
#	    	List of command to excute.
#
# Return:	exit code of ALL commands (O.K should be 0).
#
# Description:  Excute commnds. it would NOT stop by failure of single command.
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
	WrLog("Excute: $Cmd");
	@OutPut=`$Cmd 2>&1`;
	$Err=$?;
	foreach (@OutPut)
	{
	    ## chomp $_;
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
#		a record at the array. if an error ocured @lines will be
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
   	WrLog("Error - File $File not exist !");
   	$G_ErrorCounter++;
   	return;
   }
   WrLog("Info\tReading File $File");
   open INPUT,"< $File";
   $Err=$?;
   @Result=<INPUT>;
   $Err += $?;
   close INPUT ;
   $Err += $?;
   if ( $Err )
   {
   	WrLog("Error\tduring File reading error occcurred.");
   	$G_ErrorCounter++;
   	return ;
   }
   chomp @Result;
   return @Result;
}

sub BackupFile
###############################################################################
#
# Input:	$FilePath
#		$FilePath - full path of the file to backup
#
# Return:	Backup File name or "" if fail to backup.
#
# Description:  Generate backup file . the file will be copy to the same
#		directory with new name.
#
###############################################################################
{
   my $OrigFile=shift;
   my $BackFile=`date`;
   my $Suffix="Backup_";
   my $JustFile ;
   
   unless ( -e $OrigFile )
   {
   	WrLog("Error\tFail to backup file $OrigFile. file Not exists.");
   	$G_ErrorCounter++;
   	return "";
   }
   chomp $BackFile;
   $BackFile =~ /([0-9][0-9:\s]+[0-9])/;
   $BackFile =$1;
   $BackFile =~ s/://g ; 
   $BackFile =~ s/\s/_/g ;
   $BackFile = "$OrigFile.$Suffix$BackFile";
   $OrigFile =~ m/(^|\/)([^\/]+)$/ ;
   $JustFile = $2;
   WrLog ("Info\tBackup File $JustFile ...");
   if ( RunCmds("cp -p $OrigFile $BackFile") )
   {
   	$G_ErrorCounter++;
   	WrLog("Eroor\tFail to Backup File $OrigFile");
   	return "";
   }
   return $BackFile;
}

sub WriteFile #FileName @Lines  # return 0 O.K 1 Error
###############################################################################
#
# Input:	$FileName,@Content
#
# Return:	0 - for O.K , != for errors
#
# Description: Write the @Content Lines into $FileName (overwrite the file).
#
###############################################################################
{
   my $FileName=shift;
   my @Lines=@_;
   my $Err=0;
   my $Single;
   
   WrLog("Info\tWriting file $FileName.");
   open (INOUT,"> $FileName");
   if ( $? )
   {  
   	WrLog("Error\tFail to write to File $FileName");
   	return 1;
   }
   foreach $Single (@Lines)
   {
        chomp $Single;
        print INOUT "$Single\n";
        $Err += $?;
   }
   close INOUT;
   $Err += $?;
   return $Err;
}

sub UpdateFile 
###############################################################################
#
# Input:	$FileName,@Content
#
# Return:	0 - for O.K , != for errors
#
# Description: Write the @Content Lines into $FileName Don't Overwrite.
#
###############################################################################
{
   my $FileName=shift;
   my @Lines=@_;
   my $Backup=BackupFile($FileName);
   
   unless ( $Backup )
   {
       	WrLog("Error\tFail to Backup $FileName .");
 	return 1;  	    
   }
   WrLog("Info\tRewriting file $FileName.");
   if ( WriteFile($FileName,@Lines) )
   {
   	WrLog("Error\tFail to write file $FileName");
   	if ( -e $Backup )
   	{
   	    WrLog("Info\tResotring the Original file $FileName");
   	    $G_ErrorCounter += RunCmds("mv -f $Backup $FileName");
   	    return 1;
   	}
   } else
   {
   	WrLog("Note:\tTo restore the file use $Backup\n");
   }
   return 0;
}

sub UpdateHostsFile
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
    my $UnitGroupFileName="/usr/cti/conf/ftm/UnitGroup.xml";
	my $Err=$G_ErrorCounter;
	my $DomainName=`grep domain /etc/resolv.conf | cut -d ' ' -f 2`;
    print ("$DomainName");
    my @HostsFile=ReadFile($HostsFileName);
	unless ( $Err == $G_ErrorCounter )
    {
		EndProg(1,"ERROR - Failed to read Hosts file");
    }
    my @FarmsList=("MMSGW.site1","CC.NDU","NULL.site1");
    unless ( -e $UnitGroupFileName )
    {
        EndProg(1,"ERROR - UnitGroup.xml does not exist in FTM Folder , please correct it prior to running the script again");
    }
	my $Xpath;
	my ($UnitHostname,$UnitIP);
    my $Parser=XML::LibXML->new();
    my $Document=$Parser->parse_file($UnitGroupFileName);
    foreach my $AppFarm (@FarmsList)
    {
        $Xpath="/UnitGroup/Logical/Application[\@ApplicationName=\"$AppFarm\"]/UnitInstance";
        foreach my $Node ( $Document->findnodes($Xpath) )
        {
		    $UnitHostname = $Node->getAttribute("Hostname");
			$UnitIP = $Node->getAttribute("DataIp");
			WrLog ("DEBUG - Inserting $UnitHostname  $UnitIP to /etc/hosts as it appears in Farm $AppFarm");
			push(@HostsFile,"$UnitIP   $UnitHostname  $UnitHostname\.$DomainName");
		}
    }
	return (@HostsFile);
}

sub FixHost
##############################################
#  Input  @Array of Etc Hosts
#  Return - @Array without duplicate IPs
###############################################
{
	my @OldEtcHosts=@_;
	my %IndexIP;
	my @Result;
	my $Counter=0;
	foreach my $Line (@OldEtcHosts)
	{
		if ( $Line =~ /^\s*((\d+\.){3}\d+)\s+(\S.+)/ )
		{
			my $IPAddr=$1;
            my $HostList=$3;
            my $Coments;
            $HostList =~ s/(#.+)// and $Coments=$1;
            WrLog("Debug - Set Line $Counter",$Line);
            unless ( exists $IndexIP{$IPAddr} ) 
            {
                $IndexIP{$IPAddr}={ Row => $Counter ,
                Hosts => [split(/\s+/,$HostList)] ,
                Comment => $Coments };
            } 
			else
            {
                foreach my $HostName ( split(/\s+/,$HostList) )
                {
                    grep(/^$HostName$/i,@{$IndexIP{$IPAddr}->{Hosts}}) and next;
                    push(@{$IndexIP{$IPAddr}->{Hosts}},$HostName);
                }
                $IndexIP{$IPAddr}->{Comment} .= $Coments;
                next;
            }
		}
		$Counter++;
		push(@Result,$Line);
   }
   #######   Build The New Array   ####
	while ( my ($IpAddr,$IpRec) = each(%IndexIP) )
	{
        $Result[$IpRec->{Row}]=sprintf("%-16s %s $IpRec->{Comment}",$IpAddr,join(" ",@{$IpRec->{Hosts}}));
	}
   return @Result;
}


############################################################################################
#
#   					M A I N
#
############################################################################################
my (@HostsFile,@ModifiedHostsFile);
@HostsFile=UpdateHostsFile();
@ModifiedHostsFile=FixHost(@HostsFile);
UpdateFile($HostsFileName,@ModifiedHostsFile);
my $ErrMessage= $G_ErrorCounter ? "Finish with ERRORS see Log File $G_CLIParams{LogFile}" :
		"Finish Succsefully :-)";
EndProg($G_ErrorCounter,$ErrMessage);
