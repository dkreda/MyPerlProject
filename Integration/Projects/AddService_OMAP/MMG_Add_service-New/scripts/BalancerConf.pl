#!/usr/cti/apps/CSPbase/Perl/bin/perl

use strict;
use XML::LibXML;

#########################################################
#  Global variables
#########################################################

my $G_ErrorCounter=0;
my %G_CLIParams=(  LogFile  => "-" );

sub usage
{
    print "$0 [-LogFile FileName]\n";
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

sub ReadSection 
###############################################################################
#
# Input:	$Line1[,$Line2...]
#	   each $Line format must be "param=Val" there may multi params at each
#	   Line - "param1=val1;param2=val2" , "param3=val3" , "param4 ...."
#
# Return:  %Hash - contain all the key->val
#
# Description: transform from Line "param=val" to hash.
#
###############################################################################
{
    my @Input=@_;
    my (@Lines,$Iter,$Definition);
    my %Result=();
    
    foreach $Iter (@Input)
    {
    	@Lines=split(/;/,$Iter);
    	foreach $Definition (@Lines)
    	{
    	      if ( $Definition =~ m/([^=]+)=(.+)/ )
    	      {
    	      	  $Result{$1}=$2;
    	      }
    	}
    }
    return %Result;
}

sub SetSection
###############################################################################
#
# Input:	%HashParam
#
# Return:	$SingleLine
#		$SingleLine Format: param=Value;Param=Valu ....
#
# Description:  converte from Hash to singleLine.
#
###############################################################################
{
    my %HashParams=@_;
    my @ListResult=();
    
    while ( my ($Key,$Val) = each(%HashParams) )
    {
    	push(@ListResult,"$Key=$Val");
    }
    return join(";",@ListResult);
}

sub ReadConfig
###############################################################################
#
# Input:	$FileName
#		$FileName - FullPath of the configuration File to read.
#
# Return:	%Hash - format Key=Value or {SectionName}=Key=Val;Key=Val
#
# Description: read Configuration File in format key=Value. if the file
#	    has several section (such as ini file [section name]) it would
#	    return Hash in format {SectionName}=Key=Val;Key=Val...
#
###############################################################################
{
   my $File=shift;
   my $Err=$G_ErrorCounter;
   my %Result=();
   my $SectionName="";
   my $Line;
   my @Params=();
   my @Content=ReadFile($File);
   
   unless ( $Err == $G_ErrorCounter )
   {
   	EndProg(1,"Error - Fail to read Configuration file $File");
   }
   foreach $Line ( @Content )
   {
   	if ( $Line =~  m/\[([^\[\]]+)\]/  )
   	{
   	    if ( length($SectionName) > 1 )
   	    {
   	    	$Result{$SectionName}=join(";",@Params);
   	    }
   	    $SectionName=$1;
   	    @Params=();
   	    next;
   	}
   	push (@Params,$Line);
   }
   if ( $#Params >=0 )
   {
   	if ( length($SectionName) > 0  )
   	{
   	   $Result{$SectionName}=join(";",@Params);
   	} elsif ( keys (%Result) <= 0 )
   	{
   	   %Result=ReadSection(join(";",@Params));
   	}
   }
   return %Result;
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

sub IsBalancer
###############################################################################
#
# Input:	$IP
#
# Return:	0 - The Ip is Not Balancer , 1 - IP is Balancer
#
# Description:  Check if an IP is Balancer.
#
###############################################################################
{
    my $ChkIP=shift;
    my %CheckFile = ( forwarders	=> "/etc/named.conf" ,
    		      nameserver	=> "/etc/resolv.conf" );
    my $Counter=keys(%CheckFile);
    while ( my ($Param,$File) = each(%CheckFile) )
    {
    	-e $File or $Counter-- , next ;
    	my @Content=grep(/^[^#]*$Param/,ReadFile($File));
    	if ( grep(/(^|[^\d\.])$ChkIP([^\d\.]|$)/,@Content) )
    	{
    		keys(%CheckFile);
    		return 1;
    	}
    }
    $G_ErrorCounter +=  $Counter ? 0 : 1;
    return 0;
}

sub amIBalancer
###############################################################################
#
# Input:
#
# Return:
#
# Description:  0 - This Machine is not Balancer 1- This Machine is Balancer.
#
###############################################################################
{
    my $LocalIP=`hostname -i`;
    $G_ErrorCounter += $?;
    chomp($LocalIP);
    return IsBalancer($LocalIP);
}

sub UpdateBalancer
###############################################################################
#
# Input:       @Balancers IPs;
#		- List of BalacersIPs which we wish to sync
# Return:	0 - O.K    1 - Error
#
# Description:	Update Sync Parametrs at Balancer.conf
#
###############################################################################
{
    my $ConfFile="/usr/cti/conf/balancer/balancer.conf";
    my @Content=ReadFile($ConfFile);
    my %Params;
    my @BalancersIps=@_;
    
    foreach (@Content)
    {
    	if ( /\[Params\]/.../\[.+\]/ )
    	{
    	   my @Conf=split(/=/,$_);
    	   $Params{$Conf[0]}=$Conf[1];
    	} else  
    	{
    	   defined $Params{BalancerType} and last;
    	}
    }
    
    my $BalancerList=$Params{BalancerType} eq "Normal" ? "ProxyBalancerList" : "NormalBalancerList";
    $Params{EnableMultipleSite}=1;
    defined $Params{$BalancerList} and push(@BalancersIps,split(/,/,$Params{$BalancerList})) ;
    my %Ips = map { $_ => 1 } @BalancersIps ;
    $Params{$BalancerList}=join(",",keys(%Ips));
    for ( my $LineNo=0; $LineNo <= $#Content ; $LineNo++ )
    {
    	my @Conf=split(/=/,$Content[$LineNo]);
    	defined $Params{$Conf[0]} and $Content[$LineNo] =~ s/=.*/=$Params{$Conf[0]}/ ;
    }
    return UpdateFile($ConfFile,@Content);
}

sub UpdateInputApp
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
    my $FileName="/usr/cti/conf/balancer/InputApplicationList.xml";
    ##my $FileName="InputApplicationList.xml";
    my @FarmsList=("NULL.site1","MMSGW.site1","MMSGW.VOICEWRITER","PROXY.VOICEWRITER",
                                   "CC.NDU","NDS.SITE1");
    unless ( -e $FileName )
    {
                WrLog("Info - InputApplication File no Exists ...",
                      "     - if this is Insight4 System and this is balancer machine it may be a problem ...");
                return 0;
    }
    my $Xpath;
    my $Parser=XML::LibXML->new();
    my $Document=$Parser->parse_file($FileName);
    foreach my $AppFarm (@FarmsList)
    {
                $Xpath="/InputApplicationList/Application[\@ApplicationName=\"$AppFarm\"]";
                foreach my $Node ( $Document->findnodes($Xpath) )
                {
                    my $NodeName=$Node->nodeName;
                    WrLog("Info - Removing Node $NodeName - $AppFarm");
                    my $Parent = $Node->parentNode ;
            $Parent->removeChild($Node);
                }
    }
    
    ### Update MMSGW.MTA Farm ##
    $Xpath="/InputApplicationList/Application[\@ApplicationName=\"MMSGW.MTA\"]/ConnectivityCheck/Port";
    my @Nodes=$Document->findnodes($Xpath);
    my $NTmpXml = $Nodes[0];
	my $TNode;
    unless (@Nodes )
    {
        my @TNode=$Document->findnodes("//InputApplicationList");
        $TNode =$TNode[0]->appendChild(XML::LibXML::Element->new("Application"));
		$TNode->setAttribute("ApplicationName","MMSGW.MTA");
        $TNode->setAttribute("Network","Data");
        $TNode->setAttribute("NumFailuresBeforeStatus","1");
        $TNode->setAttribute("PollingIntervalCounter","6");
		$TNode->setAttribute("ReturnAllActiveIPs","1");
        $TNode->setAttribute("TTL","15");
        my $TmpXml=XML::LibXML::Element->new("ConnectivityCheck");
		$TmpXml->setAttribute("Type","Port");
        my $TmpXml2=XML::LibXML::Element->new("Port");
        $TmpXml2->setAttribute("PortNumber",50025);
        $TmpXml2->setAttribute("PortNumber2",8080);
		my $TmpXml3=XML::LibXML::Element->new("Greeting");
		$TmpXml3->setAttribute("GreatingEnabled","No");
        $TmpXml2->appendChild($TmpXml3);
        $TmpXml->appendChild($TmpXml2);
        $TNode->appendChild($TmpXml);
    }
	else
    {
        $Xpath="/InputApplicationList/Application[\@ApplicationName=\"MMSGW.MTA\"]";
        $TNode=$Document->findnodes($Xpath)->[0];
        $NTmpXml->setAttribute("PortNumber2",8080);
        $TNode->setAttribute("ReturnAllActiveIPs","1");
		$TNode->setAttribute("TTL","15");
    }
    return UpdateFile($FileName,$Document->toString);
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
    $ParamName="";
    @ParamValue=();
    while ( $#ARGV >= 0 )
    {
    	$Iter = shift(@ARGV);
    	if ( $Iter =~ m/^-(.+)$/ )
    	{
    	    $ParamName and $G_CLIParams{$ParamName}=join(',',@ParamValue);
    	    $ParamName=$1;
    	    @ParamValue=();
    	    $ParamName =~ /Help/i or next;
    	    usage();
    	    EndProg();
    	} else
    	{
    	    push(@ParamValue,$Iter);
    	}
    }
    $ParamName and $G_CLIParams{$ParamName}=join(',',@ParamValue);

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
if ( amIBalancer() and ! $G_ErrorCounter )
{
	#$G_ErrorCounter += UpdateBalancer(split(/,/,$G_CLIParams{Ips}));
	$G_ErrorCounter += UpdateInputApp();
} else
{
    WrLog("Info - This Machine is not Balancer ...");
}
my $ErrMessage= $G_ErrorCounter ? "Finish with ERRORS see Log File $G_CLIParams{LogFile}" :
		"Finish Succsefully :-)";
EndProg($G_ErrorCounter,$ErrMessage);
