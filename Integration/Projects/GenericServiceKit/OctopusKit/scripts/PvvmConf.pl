#!/usr/bin/perl

use strict;
#########################################################
#  Global variables
#########################################################

my $G_ErrorCounter=0;
my %G_CLIParams=(  ConfFile => "/usr/cti/conf/ServiceKit/PVVMConfiguration.conf",
		   LogFile  => "-" ,
		   Answer   => "/tmp/Dugma.txt" );
my %G_ConfParams=();
my $G_NetConfPath="/etc/sysconfig/network-scripts" ;

sub usage
{
    print "$0 [ConfFile Configfile]\n"
}

sub WrLog # @Lines
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

sub EndProg
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
   	WrLog("Error\tduring File reading error occcurred.");
   	$G_ErrorCounter++;
   	return ;
   }
   return @Result;
}


sub getUnit
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

sub ReadSection # param=val;param ....
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

sub PrnTitle # Lines
{
   my @InTxt=@_;
   my $TSize=70;
   my $Ch_Title="*";
   my $Border=$Ch_Title x ($TSize + 4);
   
   WrLog($Border);
   foreach my $Line (@InTxt)
   {
       chomp $Line;
       $Line =~ s/\t/  /g ;
       WrLog(sprintf ("$Ch_Title %-${TSize}s $Ch_Title\n",$Line));
   }
   WrLog($Border);
}









sub ReadBalanceParams # $BalancerIP Return %Result{}
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
    WrLog("-- Debug Flag State is $Flag");
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






sub WriteFile
{
   my $FileName=shift;
   my @Lines=@_;
   open(OUTFILE,"> $FileName");
   my $Err = $? ;
   if ( $Err )
   {
   	WrLog("Error\tFail to open $FileName (Write mode)" );
   	return $Err;
   }
   foreach (@Lines)
   {
   	print OUTFILE "$_\n";
   	$Err += $?;
   	if ( $Err ) { WrLog("-- Error while writing line \"$_\""); }
   }
   if ( $Err ) { WrLog("Error\tFail to write to file $FileName"); }
   close OUTFILE;
   $Err += $?;
   return $Err;
}







sub RunMgr #Cmd , [MipsIP] - return (@List Result)
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



sub AddKeys #$%RefHash,%Hash
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
{
    my $SpmIP=shift;
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

sub RetrievIP # DNS , @BalancersIps
{
    my $FQDN=shift;
    my @DNSList=shift;
    my $Result;
    foreach my $IpAddr (@DNSList)
    {
    	WrLog("Debug - Search $FQDN at $IpAddr ...");
    	my @Lines=`nslookup $FQDN $IpAddr`;
    	chomp @Lines;
    	my $Flag=0;
    	foreach my $Iter (@Lines)
    	{
    	   $Iter =~ /Name:/ and $Flag=1;
    	   $Flag or next;
    	   $Iter =~ /Address:\s*([\d\.]+)/ and $Result=$1;
    	}
    	$Result and last;
    }
    return $Result;
}

sub ReadGSL
{
    my @BalaceIPs=@_;
    my $ExpFile="/tmp/Test1/ReadGSL.tcl";
    my $Answer="/tmp/Gsl1.txt";
    my $Err=0;
    my @Result=();
    my $GslIP;
    #### Find GSL.Master  #####
    
    $GslIP=RetrievIP("GSL.Master",@BalaceIPs);
    WrLog("Debug - Find Gsl: $GslIP");
    unless ( $GslIP )
    {
    	$G_ErrorCounter++ ;
    	WrLog("Error - Fail to Find GSL Master IP");
    	return ;
    }
    ###  ReadGSL ####
    unless ( RunCmds("expect $ExpFile -Host $GslIP -AnswerFile $Answer") )
    {
    	my @Content=ReadFile("/tmp/Gsl1.txt");
    	my $Flag=0;
    	foreach my $Iter (@Content)
    	{
    	    $Iter =~ /-{4}/ and $Flag=1;
    	    $Flag or next;
    	    $Iter =~ /(\d+)\s+(\S+)\s+(\S+)/ or next;
    	    my %SysRec= ( ID => $1 ,
    	    		  SysName => $2 ,
    	    		  NetDomain  => $3 );
    	    $SysRec{NetDomain} =~ s/^[^\.]+\.// ;
    	    push ( @Result,\%SysRec);
    	}
    } else 
    {
    	WrLog("Error - Fail to Read GSl Table....") ;
    	$G_ErrorCounter++;
    	return ;
    }
    return @Result;
}

sub ReadIS4Conf ## @Balancer                            Delete : # IS4 BalancerIP  ## Return %Record
{
    my @BalaceIPs=@_;
    my %SysRecord=(Platform	=> "Insight4");
    my $Err=0;
    my (%Record);
    WrLog("Debug - Start Read Insight4 Configuration ....");
    my @Result=ReadGSL(@BalaceIPs);
    foreach my $SysRec (@Result)
    {
    	WrLog("Debug - Start Parssing System $$SysRec{SysName}");
    	my $TmpIP=RetrievIP("SPM.$$SysRec{NetDomain}",@BalaceIPs);
    	unless ($TmpIP)
    	{
    	    WrLog("Error - Fail to retreive compas IP for system $$SysRec{SysName}");
    	    $G_ErrorCounter++;
    	    next ;
    	}
    	%Record=ReadSpmParams($TmpIP);
    	WrLog("Debug - Compas Parameters for System $$SysRec{SysName}:");
    	while ( my ($PName,$PVal) = each (%Record) )
    	{
    	    WrLog("-D- $PName - $PVal");
    	    $$SysRec{$PName}=$PVal;
    	}
    }
    
    
    return @Result ;
    
    WrLog("-- Read Balancer Parameters ....");
    my $BalaceIP;
    %Record=ReadBalanceParams($BalaceIP);
    
    unless ( AddKeys(\%SysRecord,%Record) > 0 )
    {
    	WrLog("Error\tFail to Read Balancer parameters IP $BalaceIP.");
    	$G_ErrorCounter++;
    	return;
    }
    $SysRecord{BalncerList}=$BalaceIP;
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

my @Is4List=ReadIS4Conf(@SystemList);

foreach my $Iter (@Is4List)
{
    WrLog("Debug - IS4 System Info:");
    while ( my ($PName,$PVal) = each (%$Iter) )
    {
    	WrLog("\t- $PName = $PVal");
    }
}

exit 0;




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