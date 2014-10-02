#!/usr/bin/perl

use strict;
#########################################################
#  Global variables
#########################################################

my $G_ErrorCounter=0;
my %G_CLIParams=(  LogFile  => "-,/tmp/SQInstall.log" ,
		   ConfFile => "/usr/cti/conf/ServiceKit/MTAQueue.conf" ,
		   UpDate   => "Overwrite" );
my $G_AnswerFile="/usr/cti/conf/ServiceKit/MTAQueue.conf";

my @G_FileHandle=();

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
   	WrLog("Error - File $File not exist !");
   	$G_ErrorCounter++;
   	return;
   }
   WrLog("Info\tReading File $File");
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
   	WrLog("Error\tduring File reading error occurred.");
   	$G_ErrorCounter++;
   	return ;
   }
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
   	WrLog("Error\tFail to Backup File $OrigFile");
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

sub UpdateFile #FileName @Lines  # return 0 O.K 1 Error
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

    return $Err;
}

sub FindDest
{
    my $MailDomain=shift;
    my $Dest=shift;
    my $mgrCmd="/opt/criticalpath/global/bin/mgr -w MT#adm_iN remote route $MailDomain list";
    my @Result=();
    
    if ( $Dest =~ /(^|[,])Auto([,\:]|$)/i )
    {
    	$Dest =~ /^Auto$/ or WrLog("Error - Host definision with Auto not allowed"),return;
    	my @MgrResult=`$mgrCmd `;
    	if ( $? )
    	{
    	    WrLog("Error - Fail to retreive Routing definition for \"$MailDomain\" from MTA");
    	    $G_ErrorCounter++;
    	    return ;
    	}
    	chomp(@MgrResult);
    	@MgrResult=grep(/SMTP/,@MgrResult);
    	foreach my $Iter (@MgrResult)
    	{
    	     $Iter =~ /((\S+)\s+){3}((\S+)\s*){2}/ or WrLog("Error Compilation $Iter ...");
    	     push(@Result,"$2 PORT=$4");
    	}
    	$#Result < 0 and WrLog("Error - No Routing information for domain $MailDomain"), return;
    } else
    {
    	foreach my $HostDest ( split(/,/,$Dest) )
    	{
    	     unless ( $HostDest =~ /^([^\:]+?)(\:(\d+))?$/ )
    	     {
    	     	WrLog("Error - Destination Syntax wrong \"$HostDest\" for $MailDomain");
    	     	return;
    	     }
    	     my ($HostName,$Port)=($1,$3);
    	     $Port = length($Port) > 0 ? "$Port" : "" ;
    	     push(@Result,"$HostName $Port") ;
    	}
    }
    return @Result;
}

sub SetRoute
{
    my $DestStr=shift;
    my @DestList=split(/;/,$DestStr);
    my @Result=();
    my %DomainMap=();
    my ($MailDomain,$RouteDestStr,@Array);
    
    foreach my $RouteRul (@DestList)
    {
    	$RouteRul =~ m/^([^:]+?)(:(.+))?$/ or return ;
    	$MailDomain=$1;
    	$RouteDestStr=$3;
    	if ( exists $DomainMap{$MailDomain} )
    	{
    	    WrLog("Error - duplicate Mail domain definition $MailDomain");
    	    return ;
    	}
    	defined $RouteDestStr or $RouteDestStr="Auto";
    	my @Array=FindDest($MailDomain,$RouteDestStr);
    	$#Array < 0 and return ;
    	$DomainMap{$MailDomain}=\@Array;
    }
    while ( my ($Domain,$RouteList) = each(%DomainMap) )
    {
    	WrLog("Info - Update \"$Domain\" routing configuration");
    	push(@Result,"Clear=routedomain $Domain");
    	foreach my $Route (@$RouteList)
    	{
    	    push(@Result,"RelayRule=$Domain via $Route");
        }
    }
    return @Result;
}



sub SetMTAIP   ### 
{
    my @AllIps=@_;
    my %IpList=();
    
    foreach my $SingleStr (@AllIps)
    {
    	foreach my $OneIP (split(/[,\s]/,$SingleStr) )
    	{
    	    $IpList{$OneIP}=1;
    	}
    }
    return join(",",keys(%IpList));
}

sub getBalancerList
{
    my %SearchMap = ( "/etc/named.conf"	=> "forwarders" ,
    		    "/etc/resolv.conf"	=> "nameserver" );
    my @Result ;
    
    while ( my ($FileName,$Trriger) = each(%SearchMap) )
    {
    	my @Content=ReadFile($FileName) ;
    	my @IpList=();
    	foreach (@Content)
    	{
    	    /$Trriger/ or next;
    	    push(@IpList,$_);
 	}  
    	$#IpList < 0 and next;
    	foreach my $Ip (@IpList)
    	{
    	    while ( $Ip =~ s/((\d+\.){3}\d+)// )
    	    {
    	    	push(@Result,$1);
    	    	$Result[-1] =~ /127.0.0.1/ and pop(@Result),next;
    	    	WrLog("Info - Find DNS $Result[-1]");
    	    }
    	}
    	$#Result < 0 or last;
    }
    return @Result;
}

sub amIBalancer
{
    my $LocalIP=`hostname -i`;
    chomp $LocalIP;
    my $Result=grep(/^$LocalIP$/,getBalancerList());
    return $Result;
}

sub ReadOldconfig
{
    my $ConfFile=shift;
    my @Contenet=ReadFile($ConfFile);
    my %Result=();
    
    foreach my $Param ( @Contenet )
    {
    	$Param =~ /ManagerPassword=(.+)$/ and $Result{ManagerPassword}=$1;
    	$Param =~ /IpList=(.+)$/ and $Result{IpList} .= $1;
    }
    return %Result;
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
my @RotingContent=();
while ( my ($PName,$PVal ) = each(%G_CLIParams) )
{
     push(@DebugMessages,sprintf("\t-%-20s = $PVal",$PName));
}
WrLog(@DebugMessages);
my @Balancers=getBalancerList();
$#Balancers < 0 and $G_ErrorCounter++;
foreach my $Ip (@Balancers)
{
    push(@RotingContent,"AllowManagerIPs=$Ip 255.255.255.255");
}
my $LocalConf="/tmp/localConf.cfg";
my $MTAPassword=exists $G_CLIParams{MTAPass} ? $G_CLIParams{MTAPass} : "MT#adm_iN";
WriteFile($LocalConf,@RotingContent) or $G_ErrorCounter += RunCmds("/usr/cti/ServiceKit/SQ.pl -uq -IP 127.0.0.1 -Answer $LocalConf -MTAPass \'$MTAPassword\'") ;

if ( defined $G_CLIParams{Route} )
{
     @RotingContent=SetRoute($G_CLIParams{Route});
     $#RotingContent >=0  or $G_ErrorCounter++;
     WrLog("Debug - Configuration List:",@RotingContent);
}

unless ($G_ErrorCounter)
{
     ### Build Proxt IP List ####
     my %LastConf=ReadOldconfig($G_AnswerFile);
     my $IpStr=SetMTAIP($LastConf{IpList},$G_CLIParams{IpList});
     unshift(@RotingContent,"IpList=$IpStr");
     ### Update all rest parameters .... ###
     ##my $MTAPassword=defined $G_CLIParams{MTAPass} ? $G_CLIParams{MTAPass} : $LastConf{ManagerPassword};
     
     push(@RotingContent,"ManagerPassword=$MTAPassword");
     WrLog("Debug - Configuration List 2:",@RotingContent);
}

unless ($G_ErrorCounter or $G_CLIParams{UpDate} =~ /NoChange/i)
{
    $G_ErrorCounter +=  (-e $G_CLIParams{ConfFile} ? UpdateFile($G_CLIParams{ConfFile},@RotingContent) : WrIteFile($G_CLIParams{ConfFile},@RotingContent) );
}
my $ErrMessage= $G_ErrorCounter ? "Finish with ERRORS see Log File $G_CLIParams{LogFile}" :
		"Finish Successfully :-)";
## $G_ErrorCounter++;		
EndProg($G_ErrorCounter,$ErrMessage);
