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
#########################################################
#  Global variables
#########################################################

my $G_ErrorCounter=0;
my %G_CLIParams=(  ConfFile => "/usr/cti/conf/ServiceKit/PVVMConfiguration.conf",
		   LogFile  => "-" ,
		   Answer   => "/tmp/Dugma.txt" );
my @G_FileHandle=();
my %G_ConfParams=();
my $G_NetConfPath="/etc/sysconfig/network-scripts" ;

sub usage
{
    print "$0 [ConfFile Configfile]\n" ;
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
# Description:  convert from Hash to single Line.
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
#		[$BackupFolder] - optional
#
# Return:	Backup File name or "" if fail to backup.
#
# Description:  Generate backup file . the file will be copy to the same
#		directory with new name.
#
###############################################################################
{
   my ($OrigFile,$BackFile)=@_;
   my $Suffix="Backup_";
   my @DArr=localtime();
   my $JustFile=$OrigFile ;
   
   unless ( -e $OrigFile )
   {
   	WrLog("Error\tFail to backup file $OrigFile. file Not exists.");
   	$G_ErrorCounter++;
   	return ;
   }
   my $Counter=1;
   $JustFile =~ s/^.*\/// ;
   $BackFile = $BackFile ? "$BackFile/$JustFile" : 
   	sprintf("$OrigFile.$Suffix%4d_%02d_%02d_%02d%02d%02d",$DArr[5]+1900,$DArr[4]+1,$DArr[3],$DArr[2],$DArr[1],$DArr[0]);
   ### Make sure there is no duplicate backup Files ####
   while ( -e $BackFile )
   {
   	$BackFile .= "$Counter" ;
   	$Counter++;
   }
   
   WrLog ("Info\tBackup File $JustFile ...");
   if ( RunCmds("cp -p $OrigFile $BackFile") )
   {
   	$G_ErrorCounter++;
   	WrLog("Eroor\tFail to Backup File $OrigFile");
   	return ;
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
#		Note - If File name syntax is "Name,Name2" then Name2 is the 
#			backup Folder ...."
# Return:	0 - for O.K , != for errors
#
# Description: Write the @Content Lines into $FileName Don't Overwrite.
#
###############################################################################
{
   my @TmpArray=split(/,/,shift);
   my @Lines=@_;
   my $Backup=BackupFile(@TmpArray);
   
   unless ( $Backup )
   {
       	WrLog("Error\tFail to Backup $TmpArray[0] .");
 	return 1;  	    
   }
   WrLog("Info\tRewriting file $TmpArray[0].");
   if ( WriteFile($TmpArray[0],@Lines) )
   {
   	WrLog("Error\tFail to write file $TmpArray[0]");
   	if ( -e $Backup )
   	{
   	    WrLog("Info\tRestoring the Original file $TmpArray[0]");
   	    $G_ErrorCounter += RunCmds("mv -f $Backup $TmpArray[0]");
   	    return 1;
   	}
   } else
   {
   	WrLog("Note:\tTo restore the file use $Backup\n");
   }
   return 0;
}

sub RunMgr #Cmd , [MipsIP] - return (@List Result)
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
    my $MgrPath="/opt/criticalpath/global/bin/mgr";
    my $Request=shift;
    my $Server=shift;
    my $MgrCmd="-w A25Trk7B43" . ($Server ? " -s $Server"  : "") ;
    my $LastLine;
    my @Responce=();
    unless ( -e $MgrPath )
    {
    	WrLog("Error\tMTA (mgr) is not install on this machine. Skip the Request");
    	return "Error - no mgr" ;
    }
    ## WrLog("--Debug mgr Command \"$MgrPath $MgrCmd $Request\"");
    @Responce=`$MgrPath $MgrCmd $Request 2>&1`;
    chomp(@Responce);
    $LastLine=pop(@Responce);
    unless ( $LastLine eq "OK" )
    {
    	WrLog("Error\tMgr command failed:\n@Responce\n$LastLine");
    	## return ($LastLine,@Responce);
    }
    return ($LastLine,@Responce);
}


sub getUnit
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
    my $Conf="/usr/cti/conf/babysitter/Babysitter.ini";
    my $Param="UnitType=";
    
    my $Unit=`grep $Param $Conf`;
    if ( $? )
    {
    	$G_ErrorCounter++;
    	WrLog("Error: Fail to get Machine unit type");
    	return ;
    }
    	
    chomp ( $Unit );
    $Unit =~ /=(.+)$/ ;
    return $1;
}

sub ReadBalanceParams # $BalancerIP Return %Result{}
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
    my $BalancerIP=shift;
    my %Result=();
    my $AnswerFile="/tmp/Answer.txt";
    my @ParamList=("NetworkDomain","SystemID","MailDomain","Validate");
    my $Flag="Skip";
    my $ExpFile="ReadBalancer.tcl";
    my $Err=0;
    
    foreach (@ParamList)
    {
    	if ( $G_ConfParams{$_} =~ m/^(Auto|Yes)$/i )
    	{
    	   $Flag="Auto";
    	}else
    	{
    	   $Result{$_}=$G_ConfParams{$_};
    	}
    }
    WrLog("Debug - Flag State is $Flag");
    if ( $Flag ne "Skip" && ! -e $ExpFile )
    {
    	WrLog("Error - missing Expect File $ExpFile","-Debug Current Path is" . `pwd`);
    }
    unless ( $Flag eq "Skip" )
    {
    	##$Err+=RunCmds("expect $ExpFile $BalancerIP");
    	$Err+=RunCmds("expect $ExpFile -Host $BalancerIP -AnswerFile $AnswerFile");
    	unless ( $Err )
    	{
    	   %Result=ReadConfig($AnswerFile);
    	   if ( length(keys(%Result)) < 0 )
    	   {
    	   	WrLog("Error - Fail to read Balancer Result file ...");
    	   	%Result=();
    	   }
    	}
    }    
    return %Result
}


sub AddKeys #$%RefHash,%Hash
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
    my $RefHash=shift;
    my $Count=0;
    my %NewHash=@_;
    while ( my ($Key,$Val) = each(%NewHash) )
    {
    	${$RefHash}{$Key}=$Val;
    	$Count++;
    }
    return $Count;
}

sub LineToHash # $Line
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
    my $Input=shift;
    my @Content=split(';',$Input);
    my $Key="";
    my %Result=();
    
    ## WrLog("-- Debug Hash Input $Input");
    foreach ( @Content )
    {
	if ( length($Key) > 0 )
	{
	   $Result{$Key}=$_;
	   $Key="";
	} else { $Key=$_; }
    }
    
    if ( length($Key) > 0 )
    {
    	WrLog("Warning - Empty Parameter at Hash \"$Key\" will be ignore");
    }
    return %Result;
} 

sub WrConf #FileName , DefaultSys, @ListOfSys
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
    my $FileName=shift;
    my $DefSys=shift;
    my @SysList=@_;
    my %SysIDParam=( Insight4	=>	"SystemID" ,
    		     Insight3	=>	"TRM_ID" );
    my ($SysLine,%SysRecord,$SysID);
    my @FileLines=();
    
    foreach $SysLine (@SysList)
    {
    	%SysRecord=LineToHash($SysLine);
    	$SysID=$SysIDParam{$SysRecord{Platform}};
    	unless ( defined $SysRecord{$SysID} )
    	{
    	    my $Message= defined $SysRecord{Platform} ? "unsupported platform $SysRecord{Platform}" :
    	    		 "missing platform parameter" ;
    	    WrLog("Error\t$Message. Skip configuration of this system.");
    	    next;
    	}
    	push(@FileLines,"[System$SysRecord{$SysID}]");
    	while ( my ($Key,$Val) = each(%SysRecord) )
    	{
    	    push(@FileLines,"$Key=$Val");
    	}
    	push(@FileLines,"\n");
    }
    PrnTitle("-- Debug Write File $FileName :",@FileLines);
    return WriteFile($FileName,@FileLines);
}
    
sub CustomIS4 # $DefaultSys , @listofSys
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
   my $DefSys=shift;
   my @SysList=@_;
   my ($SysLine,%SysRecord,@Description);
   my $Resolv="/etc/resolv.conf";
   
   foreach $SysLine (@SysList)
   {
   	%SysRecord=LineToHash($SysLine);
   	@Description=("System '$SysRecord{SystemID}' Parameters:");
    	while ( my ($Key,$Val) = each  (%SysRecord) ) { push(@Description,"\t$Key --> $Val"); }
    	PrnTitle(@Description);
    	## Only for CAS Unit !!!
    	if ( $DefSys eq $SysRecord{SystemID} )
    	{
    	    WrLog("- System $SysRecord{SystemID} is the Default System",
    	    	  " -- set Network domain...to $SysRecord{NetDomain}");
    	    ## Update /etc/Resolv
   
    	    if ( $G_CLIParams{Unit} eq "CAS" )
    	    {
    	    	WrLog(" -- set SystemID...to $SysRecord{SystemID}");
    	    	# txt:///usr/cti/conf/genesis/JGlue/jglue/osa/osa/profile/ComPAS.properties//[s=]SystemId
    	    }
    	}
    	## Only for Proxy Unit !!!
    	if ( $G_CLIParams{Unit} eq "PROXY" )
    	{
   	    WrLog("Info\tset MailDomain...to $SysRecord{MailDomain}");
   	    ## Update defaults: /opt/criticalpath/global/filters/default
   	}
   	
   }
}

sub ValidateParams
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
    my %Result=();
    my $RecPoint=shift;
    my $ExpFile="ReadCodec.tcl";
    my $AnswerFile="/tmp/Answer.txt";
    my $Err=0;
    my %Stam=%$RecPoint;
    foreach ( keys(%Stam) )
    {
    	WrLog("-- Key: $_ -> $Stam{$_}")
    }
    if ( $Stam{VxV_IP} =~ /[0-9]+(\.[0-9]+){3}/ )
    {
    	$Err += RunCmds("expect $ExpFile -Host $Stam{VxV_IP} -AnswerFile $AnswerFile");
    } else { $Err=1; }
    unless ( $Err )
    	{
    	   %Result=ReadConfig($AnswerFile);
    	   if ( length(keys(%Result)) < 0 )
    	   {
    	   	WrLog("Error - Fail to read Balancer Result file ...");
    	   	%Result=();
    	   }
    	}
    return %Result;
}

sub ReadSpmParams
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
    my $SpmIP=shift;
    $SpmIP =~ s/,.*$// ;
    my $ExpFile="ReadSpm.tcl";
    my $AnswerFile="/tmp/Answer.txt";
    my %Result=();
    my $Err=0;
    #$Err += RunCmds("expect $ExpFile $SpmIP");
    $Err += RunCmds("expect $ExpFile -Host $SpmIP -AnswerFile $AnswerFile");
    unless ( $Err )
    {
    	%Result=ReadConfig($AnswerFile);
    	while ( my ($Key,$Val) = each(%Result) )
    	{
    	      $Val =~ s/A://g ;
    	      $Result{$Key} = $Val ;
    	}
    }
    return %Result;
}

sub ReadMipsParams # MipsIP
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
    my $MipsIP=shift;
    my $ExpFile="ReadMaildomain.pl";
    my %Result=();
    my $Err=0;
    my $Iter;
    my (@Domains,@MailDomains);
    ##$Err += RunCmds("$ExpFile $MipsIP");
    @Domains=RunMgr("DOMAIN LIST",$MipsIP);
    @MailDomains=();
    $Err = shift (@Domains);
    if ($Err ne "OK" )
    {
    	return %Result;
    }
    
    foreach $Iter (@Domains)
    {
    	$Iter =~ s/^[*\s]+// ;
    	my @Lines=RunMgr("DOMAIN SHOW $Iter",$MipsIP);
    	$Err = shift (@Lines);
    	if ($Err ne "OK" )
    	{
    	    WrLog("Error\tFail to check domain $Iter:",@Lines,"==========");
    	    next;
    	}
    	## WrLog("-- Debug Chek Domain \"$Iter\" ...");
    	foreach (@Lines)
    	{
    	    if ( $_ =~ m/CLASS|SWITCH/ )
    	    {
    	    	push(@MailDomains,$Iter);
    	    	## WrLog("-- Debug Domain \"$Iter\" is valid");
    	    	last;
    	    }
    	}
    }
    unless ( $#MailDomains < 0 )
    {
    	$Result{MailDomain}=join(',',@MailDomains);
    }
    return %Result;
}

sub Insight3Conf ## trmIP
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
    my @TrmIPList=();
    my $TrmIP=shift;
    my $AnswerFile="/tmp/IS3Answer.txt";
    my $Err=0;
    my $MSUIP=0;
    
    WrLog("Info\t-- Start Parsing Insight3 system --");
    $Err += RunCmds("expect ReadTrm.tcl -Host $TrmIP -AnswerFile $AnswerFile");
    if ( $Err )
    {
    	EndProg(1,"Fatal\tFail to read trm configuration.");
    }
    ##WrLog("-- Ignore This Error...");
    my %Result=ReadConfig($AnswerFile);
    my %Acumulator;
    foreach $TrmIP ( keys(%Result) )
    {
    	if ( $TrmIP =~ /^MSU/i )
    	{
    	    if ( $Result{$TrmIP} =~ /[0-9](\.[0-9]+){3}/ )
    	    {
    	    	WrLog("Info\tFind Match MSUIP $TrmIP -> $Result{$TrmIP}");
    	    	$MSUIP=$Result{$TrmIP};
    	    	last;
    	    }
    	}
    }
    	    	
    if ( $MSUIP )
    {
    	$Err += RunCmds("rm -f $AnswerFile" ,
    		"expect ReadMSU.tcl -Host $MSUIP -AnswerFile $AnswerFile");
    	unless ( $Err )
    	{
    	   %Acumulator=ReadConfig($AnswerFile);
    	   $Result{MIPS_IP} = $Acumulator{Mips} =~ /[0-9]+\./ ? $Acumulator{Mips} : 0;
    	} else { WrLog("Error\tFail to read MSU Parameters..."); }
    	
    }
    if ( $Result{MIPS_IP} )
    {
    	%Acumulator=ReadMipsParams($Result{MIPS_IP});
    	unless ( AddKeys(\%Result,%Acumulator) > 0 )
    	{
       		WrLog("Error\tFail to Read domain from Mips ($Result{Mips}).");
       		$G_ErrorCounter++;
       	}
    }
    $Result{Platform}="Insight3";
    return %Result;
}

sub ReadGSL
###############################################################################
#
# Input: $OracleIP
#
# Return:  @\%SysRecords
#
# Description:
#
###############################################################################
{
     my $OraIP=shift;
     my $ExpFile="ReadGSL.tcl";
     my $AnswerFile="/tmp/SqlAnswer.txt";
     my @Result=();
     my $Err=0;
     my $Iter;
     
     WrLog("Debug - Parssing Oracle $OraIP");
     if ( RunCmds("expect $ExpFile -Host $OraIP -AnswerFile $AnswerFile") )
     {
     	WrLog("Error - failed to read configuration from Oracle");
     	$G_ErrorCounter++;
     	return ;
     }
     my @Lines=ReadFile($AnswerFile);
     my $Title; 
     while ( $Title !~ /GROUP_ID.+GROUP_NAME.+COSHOSTNAME/ )
     {
     	$Title=shift(@Lines);
     }
     $Title=shift(@Lines);
     foreach my $Line (@Lines)
     {
     	$Line =~ /(\d+)\s+(\S+)\s+.+?\.(\S+)/ or WrLog("Warning - Mismatch Line:","\t$Line"),next;
     	my %SysRec;
     	$SysRec{SysID}=$1;
     	$SysRec{Name}=$2;
     	$SysRec{NetworkDomain}=$3;
     	push(@Result,\%SysRec);
     }
     ## %Result = ReadConfig($AnswerFile);
     return @Result;
}

sub getAllIps
###############################################################################
#
# Input:	[$ServerIP],@ListDomain
#		$ServerIP
# Return:       @ListofIps
#
# Description: Retreive List of Ips that match the List of Domains -
#		use nslookup method ...
#
###############################################################################
{
    my $ServerIP=shift;
    my @ListOfDomains=@_;
    my (@Result,%IpList,$IPNumber,$Err);
    $ServerIP =~ /^(\d+\.){3}\d+$/ or unshift(@ListOfDomains,$ServerIP),undef $ServerIP;
    
    foreach my $FQDN (@ListOfDomains)
    {
    	$Err=0;
    	while ( $Err == 0 )
    	{
    		my @AnswerList = `nslookup $FQDN $ServerIP`;
    		$Err += $?;
    		$Err and WrLog("Warning - Last nslookup command ($FQDN $ServerIP) return error");
    		chomp @AnswerList;
    		$IPNumber=0;
    		foreach my $Line ( @AnswerList )
    		{
    	     		$Line =~ m/Name.+$FQDN/ and $IPNumber=1;
    	     		$IPNumber and $Line =~ m/Address.+\s+(\S+)$/ and $IPNumber=$1;
    		}
    		$IPNumber =~ /(\d+\.){3}/ or last;
    		exists($IpList{$IPNumber}) and last;
    		$IpList{$IPNumber}=1;
    		WrLog("Debug - Add The IP $IPNumber as retreive from \"$FQDN\"");
    	}
    }
    @Result=keys(%IpList);
    return @Result;
}


sub ReadIS4Conf # IS4 BalancerIP  ## Return %Record
###############################################################################
#
# Input:	$BalancerIP
#
# Return:
#
# Description:
#
###############################################################################
{
    my $BalaceIP=shift;
    my %SysRecord=(Platform	=> "Insight4");
    my $Err=0;
    my (%Record);
    
    WrLog("Info - Read Balancer Parameters ....");
    WrLog("Info - Get GSL-Oracle Ip access ...");
    my @GSLNames= ("GSL.Master","GSL.multisite","ODS");
    my $OraIP=0;
    foreach my $OraName (@GSLNames)
    {
    	my @AnswerList = `nslookup $OraName $BalaceIP`;
    	chomp @AnswerList;
    	foreach my $Line ( @AnswerList )
    	{
    	     $Line =~ m/Name.+$OraName/ and $OraIP=1;
    	     $OraIP and $Line =~ m/Address.+\s+(\S+)$/ and $OraIP=$1;
    	}
    	$OraIP =~ /\d+\./ and last;
    	WrLog("Debug - Could nt resolvr Oracle IP from the Name \"$OraName\":",@AnswerList,"");
    	$OraIP = 0;
    }
    
    WrLog("Info - GSL IP: $OraIP");
    AddKeys(\%SysRecord,{ GSLIP => $OraIP });
 #   ("NetworkDomain","SystemID","MailDomain","Validate")
#    %Record=ReadBalanceParams($BalaceIP);
#    unless ( AddKeys(\%SysRecord,%Record) > 0 )
#    {
#    	WrLog("Error\tFail to Read Balancer parameters IP $BalaceIP.");
#    	$G_ErrorCounter++;
#    	return;
#    }
    $SysRecord{BalncerList}=$BalaceIP;
    WrLog("Info - Reading GSL parameters from oracle ...");
    %Record =ReadGSL($OraIP);
    keys %Record > 0 or return ;
    AddKeys(\%SysRecord,%Record);
    
    
    WrLog("-- Read Spm Parameters ...");
    if ( $G_ConfParams{SystemID} =~ /Auto/i )
    {
    	if ( $SysRecord{SPM_IP} !~ /[0-9]+(\.[0-9]+){3}/ )
    	{
    	   WrLog("Error\tFail to retreive SPM IP:\"$SysRecord{SPM_IP}\"");
    	   $G_ErrorCounter++;
    	   return %SysRecord;
    	} 
    	%Record=ReadSpmParams($SysRecord{SPM_IP});
    }else 
    {
    	%Record=();
    	$Record{SystemID}=$G_ConfParams{SystemID}
    }
    unless ( AddKeys(\%SysRecord,%Record) > 0 )
    {
       	WrLog("Error\tFail to Read Spm parameters from $SysRecord{SPM_IP}.");
       	$G_ErrorCounter++;
       	return %SysRecord;
    }
    WrLog("-- Read Mips Parameters ...");
    if ( $G_ConfParams{MailDomain} =~ m/(^|,)Auto(,|$)/i )
    {
    	unless( $SysRecord{MIPS_IP} =~ /[0-9](\.[0-9]+){3}/ )
    	{
    	    WrLog("Error\tIlegal Mips IP $SysRecord{SPM_IP}.");
       	    $G_ErrorCounter++;
       	    return %SysRecord;
       	}
    	WrLog("-- Call ReadMipsParams with Params $SysRecord{MIPS_IP}");
    	%Record=ReadMipsParams($SysRecord{MIPS_IP});
    }else
    {
    	%Record=();
    	$Record{MailDomain}=$G_ConfParams{MailDomain}
    }
    unless ( AddKeys(\%SysRecord,%Record) > 0 )
    {
       	WrLog("Error\tFail to Read MIPS parameters from $SysRecord{MIPS_IP}.");
       	$G_ErrorCounter++;
       	return %SysRecord;
    }
    WrLog("-- Finish Reading Insight4 copnfiguration ...");
    return %SysRecord;
}

sub ReadCLI #update %G_CLIParams
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
    	} else
    	{
    	    push(@ParamValue,$Iter);
    	}
    }
    $G_CLIParams{$ParamName}=join(',',@ParamValue);
    unless ( defined $G_CLIParams{Unit} )
    {
    	$G_CLIParams{Unit}=getUnit();
    	$Err += $G_ErrorCounter;
    }
    return $Err;
}



############################################################################################
#
#   					M A I N
#
############################################################################################

#ReadCLI Params
my %SysRecord=();
my %Record;
my $HashSize;
my @Description;
my @SysList=();
my $SysDefault="";

undef $SysDefault;
if ( ReadCLI() )
{
    usage();
    EndProg(1);
}
#Readconffile
%G_ConfParams=ReadConfig($G_CLIParams{ConfFile});

WrLog("-- Debug Configuration List:");
foreach ( keys(%G_ConfParams) )
{
    WrLog("-- $_ => $G_ConfParams{$_}");
}

my @SystemList=split(',',$G_ConfParams{BalncerList});
my %SysConfig=();
#%SysRecord=Insight3Conf($G_ConfParams{TRM_IP});
#push(@SysList,join(';',%SysRecord));

### New PVVM Retreival
my (@OracleIps,%UniIP);
foreach my $BalnceIP (@SystemList)
{
    my @TmpList=getAllIps($BalnceIP,"GSL.Master","GSL.multisite","ODS");
    foreach (@TmpList) { $UniIP{$_}=1; }
}

###  Make sure there just one IP for each Oracle  ... ###
@OracleIps = keys(%UniIP);

### if @OracleIps is empty - then all Balancers r IS3 ... skip is4
WrLog("debug - Number of Oracles $#OracleIps");
### if Is4 ...
my @SysRecList;
my @ServerList=("MIPS1","Profile1","ODS","DSUHTTP1","SPM");
unless ( $#OracleIps<0 )
{
    ###  Read GSL info from Oracle  ##
    foreach my $OracleIp (@OracleIps)
    {
    	WrLog("===============","#### Debug Reading Oracle $OracleIp ...#####","==============","","");
    	my @TmpList=ReadGSL($OracleIp);
    	push(@SysRecList,@TmpList);
    }
    
    foreach my $SysRecPointer (@SysRecList)
    {
    	my $NetDomain=$$SysRecPointer{NetworkDomain};
    	WrLog("Debug - Using nework domain $NetDomain");
    	foreach my $ResName (@ServerList)
    	{
    	   my @TmpIPs ;
    	    for ( my $i=0 ; $i<= $#SystemList ; $i++ )
    	    {
    	    	@TmpIPs=getAllIps($SystemList[$i],"$ResName.$NetDomain");
    	        $#TmpIPs < 0 or last;
    	    }
    	   $$SysRecPointer{$ResName}=join(',',@TmpIPs);
    	   $#TmpIPs < 0 and WrLog("Error - fail to get $ResName IPs");
    	}
    }
    WrLog("Debug - Read SPM Params");
    foreach my $SysRecPointer (@SysRecList)
    {
    	
    	my %Record=ReadSpmParams($$SysRecPointer{SPM});
    	AddKeys($SysRecPointer,%Record);
    	
    }	
    WrLog("Debug - Mips configuration Read ...");
}

WrLog("Debug - sun of system Report:");
foreach my $SysRecPointer (@SysRecList)
{
	WrLog("Debug - System Info:");
    	while ( my ($Param,$Pval) = each(%$SysRecPointer) )
    	{
    		WrLog("\t$Param => $Pval");
    	}
}

my $MMM=$G_ErrorCounter ? "Finsish with errors" : "Finish succesful ignore the octopus error !";
EndProg(1,$MMM);
### foreah $OracleServer (@OracleIps)
##    @ListOfSysRecords=ReadGSL($OracleServer);
###    push(@GlobalGSLList,@ListOfSysRecords);

###  foreach $SysRecPointer (@GlobalGSLList)
##      foreach $ResName ("Mips1",Profile1,ODS,dsuhttp1,spm)
##      	@TmpIps=getAllIps
##              if @TmpIps s not empty $SysRecPointer{ResName}=join Ips

###    Start to check at Mips domains ....

foreach my $Iter (@SystemList)
{
    %SysRecord=ReadIS4Conf($Iter);
    unless ( keys(%SysRecord) > 0 )
    {
    	WrLog("Error\tSkip Configuration of System IP $Iter. due to errors ( see log ).");
    	next;
    }
    push(@SysList,join(';',%SysRecord));
    unless ( defined $SysDefault )
    {
    	$SysDefault=$SysRecord{SystemID};
    }
}
if ( $G_ConfParams{Validate} )
{
    my $DefSysNum=0;
    foreach my $Iter ( @SysList )
    {
    	%Record=LineToHash($Iter);
    	if ( $Record{SystemID} eq $SysDefault ) { last; }
    	$DefSysNum++;
    }
    ## PrnTitle("Start Validation Configration","Use Default System Record $DefSysNum");
    my %Result = ValidateParams(\%Record);
    $HashSize=keys(%Result);
    if ( $HashSize <=0 )
    {
    	WrLog("Error\tFail get Validation parameters from Pvvm");
    }
    #while ( my ($Key,$Val) = each(%Result) )
    #{
   # 	WrLog("Info\tVerify $Key -> $Val");
    #}
    my $Temp=join(';',%Result);
    if ( length($Temp) > 0 ) { $SysList[$DefSysNum] .= ";$Temp"; } 
}
## PrnTitle("Finish To Read Configuration.");
##CustomIS4($SysDefault,@SysList);
$G_ErrorCounter += WrConf($G_CLIParams{Answer},$SysDefault,@SysList);
my $Message = $G_ErrorCounter > 0 ? "Error\tFail to Read all configuration. see Log $G_CLIParams{LogFile}" :
		"Ignore This Error..." ;
EndProg($G_ErrorCounter,$Message);