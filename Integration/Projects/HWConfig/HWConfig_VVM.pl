#!/usr/bin/perl

use strict;
#########################################################
#  Global variables
#########################################################

my $G_ErrorCounter=0;
my %G_CLIParams=(  Conf		=> "/usr/cti/conf/ServiceKit/HardwareConfig.ini",
		   LogFile 	=> "-" );
my $G_CspPath="/usr/cti/apps/CSPbase";
my %G_HWList=();


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
	    chomp $_;
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


sub getHWType # Return the HW Type
{
    my $Err=0;
    my $Result=`cat /etc/.machine`;
    my $Err=$?;
    $Err and $Result="";
    $Result = length($Result) < 2 ? `$G_CspPath/csp_scanner.pl --machine_type` : $Result ; 
    $Err=$?;
    if ( $Err )
    {
    	WrLog("Warning\tFail to retreive Hardware Type.",
    	      "       \tThis may cause if CSP BASE is not install on this machine." ,
    	      "       \tscript will use default customization." );
    }
    chomp $Result;
    $G_ErrorCounter += $Err;
    return $Result;
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

sub ReadConfig # Filename  ###Return List of Sections / or Params of single section
{
   my $File=shift;
   my $Err=0;
   my %Result=();
   my $HWName="";
   my $Line;
   my @Params=();
   unless ( -e $File )
   {
   	EndProg(1,"Error - File $File not exist !");
   }
   WrLog("- Read configuration File $File");
   open INPUT,"< $File";
   $Err=$?;
   while ( <INPUT> )
   {
   	$Line=$_;
   	chomp $Line;
   	if ( $Line =~  m/\[([^\[\]]+)\]/  )
   	{
   	    if ( length($HWName) > 1 )
   	    {
   	    	$Result{$HWName}=join(";",@Params);
   	    }
   	    $HWName=$1;
   	    @Params=();
   	    next;
   	}
   	push (@Params,$Line);
   }
   close INPUT ;
   $Err += $?;
   if ( $Err )
   {
	EndProg(1,"Error - Fail to read $File");
   }
   if ( $#Params >=0 )
   {
   	if ( length($HWName) > 0  )
   	{
   	 ##  print "-- Debug Title is \"$HWName\" length " , length($HWName) , "\n";
   	   $Result{$HWName}=join(";",@Params);
   	} elsif ( keys (%Result) <= 0 )
   	{
   	   %Result=ReadSection(join(";",@Params));
   	}
   }
   return %Result;
}


sub WrLog # @Lines
{
    my @Lines=@_;
    unless ( defined fileno(LOGFILE) || $#Lines < 0 )
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

sub PrnTitle # Lines
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

sub EndProg # [$ExitCod , [@Text]]
{
     my $ExitCode=shift;
     WrLog(@_);
     if ( defined fileno(LOGFILE) )
     {
     	close LOGFILE ;
     }
     exit $ExitCode;
}

sub getUnit
{
    my $Conf="/usr/cti/conf/babysitter/Babysitter.ini";
    my $Param="UnitType=";
    
    my $Unit=`grep $Param $Conf`;
    if ( $? )
    {
    	$G_ErrorCounter++;
    	WrLog("Error\tFail to get Machine unit type");
    	return ;
    }
    	
    chomp ( $Unit );
    $Unit =~ /=(.+)$/ ;
    return $1;
}

sub getMachineConf # ConfFile,HWMachine , Unit
{
   my $File=shift;
   my $HWType=shift;
   my $Unit=shift;
   my (@Params,@Vals,$Iter);
   my %HWList=ReadConfig($File);
   my %Result=();
   ### Fix for PSG00620816
   my $SecCounter=0;
   
   foreach $Iter ($HWType,"$HWType/$Unit")
   {
   	defined $HWList{$Iter} or next;
   	$SecCounter++;
 	my %TempTable=ReadSection($HWList{$Iter});
   	while ( my ($Param,$Val) = each(%TempTable) )
   	{
   	    $Result{$Param}=$Val;
   	}
   }
   	    
   unless ( $SecCounter )
   {
   	### Fix for PSG00620816
   	WrLog "Error\tUnsupported Hardware \"$HWType\". Check if $File is update.";
   	$G_ErrorCounter++;
   	return ;
   }
   return %Result;
}

sub BackupFile #Full Path name
{
   my $OrigFile=shift;
   my $BackFile=`date`;
   my $JustFile ;
   
   unless ( -e $OrigFile )
   {
   	WrLog "ERROR\tFail to backup file $OrigFile. file Not exists.";
   	$G_ErrorCounter++;
   	return "";
   }
   chomp $BackFile;
   $BackFile =~ /([0-9][0-9:\s]+[0-9])/;
   $BackFile =$1;
   $BackFile =~ s/://g ; 
   $BackFile =~ s/\s/_/g ;
   $BackFile = "$OrigFile.ServiceKit.Backup_$BackFile";
   $OrigFile =~ m/(^|\/)([^\/]+)$/ ;
   $JustFile = $2;
   WrLog "- Backup File $JustFile ...";
   $JustFile = RunCmds("cp -p $OrigFile $BackFile");
   $G_ErrorCounter += $JustFile;
   if ( $JustFile )
   {
   	WrLog "Error\tFail to Backup File $OrigFile";
   	return "";
   }
   return $BackFile;
}

sub usage
{
    $0 =~ m/([^\\\/>]+)$/ ;
    my @Lines=("$1 Set parameters depends on HW Type. usage:",
    	"$1 [-Conf <HW configuration file>] [-LogFile <Log file>] [-Unit Unit type (CAS|PROXY|WIS|MTS)]",
    	"\t- Conf:     Name + Path of Hardware configuration file. for more details about",
    	"\t\t\tHardware configuration file, list of parameters etc see the comment on configuration file",
    	"\t- LogFile:  Name + path of the log file for this script",
    	"\t- Unit:     Defines the Unit Type (CAS|PROXY|WIS|MTS)." ,
    	"\t\t\tIf this info is omitted from command line - the script check the value at babystter",
    	"\t\t\tconfiguration file." );
    
    foreach (@Lines)
    {
    	print "$_\n";
    }
}

sub ReadCLI
{
   my ($Iter,$Param,@Lines);
   
   @Lines=("Info\tInput: ". join(" ",@ARGV));
   while ( $#ARGV >= 0 )
   {
   	$Iter=shift(@ARGV);
   	unless ( $Iter =~ m/^-(.+)/ )
   	{
   	   unless ( $Param )
   	   {
   	   	WrLog("Error: unknown command line parametr \"$Iter\"",
   	   	      "see usage: $0 -help");
   	   	usage();
   	   	EndProg(1,"Exit Due to command line error");
   	   }
   	   $G_CLIParams{$Param} = $Iter;
   	} else
   	{
   	   $Param=$1;
   	   if ( $Param =~ /^(Help|h$)/i )
   	   {
   	   	usage();
   	   	EndProg();
   	   }
   	}
   }

   ## Set defaults
   unless ( defined $G_CLIParams{Unit} )
   {
   	$G_CLIParams{Unit}=getUnit();
   }
   push(@Lines,"Info\tScript Initial parameters:");
   foreach ( keys (%G_CLIParams) )
   {
   	push(@Lines,sprintf ("\t%-10s = %30s\n",$_,$G_CLIParams{$_}));
   }
   push(@Lines,'=' x 60 , "\n");
   WrLog(@Lines);
}

sub ParamsList # ParamName , Value # return %ActualParams parma => value
{
    my $ParamName=shift;
    my $ParamVal=shift;

	###   fix for DR-0-191-962 - Setting number of threads for the MTS (on MTS-U)
	
	if ( $ParamVal =~ /(\d+)\s*Per\s+Core/i ) 
	{
		my $Tmp=$1;
		my @List1=`mpstat -P ALL`;
		$ParamVal = $Tmp * ($List1[-1] =~ /((\S+)\s*){3}/ ? $2 + 1 : -1 );
		$ParamVal < 0 and WrLog("Error - Fail to retreive number of Cores on this machine"),$G_ErrorCounter++;
	}

    my %ParamRec=( NumOfConnections   => "MaxNumOfConnection=$ParamVal" ,
    		   NumOfThreads		  => 
    		     sprintf("NumOfThreads=%d;NumberOfBusyThreadsMaxThreshold=%d;NumberOfBusyThreadsHighThreshold=%d;NumberOfBusyThreadsMinThreshold=%d",
    		              $ParamVal,0.95*$ParamVal,0.9*$ParamVal,0.85*$ParamVal) ,
    		   JavaMem		  => "JAVA_OPTS=$ParamVal" ,
    		   Genesis_ProcessMem	  =>
    		     sprintf("MemTerminateLevel=%d;MemWarningLevel=%d",$ParamVal,0.95*$ParamVal) ,
			   WebInbox_ProcessMem	  =>
    		     sprintf("MemTerminateLevel=%d;MemWarningLevel=%d",$ParamVal,0.95*$ParamVal) ,
				cas_Aumsi_ProcessMem	  => 
    		     sprintf("MemTerminateLevel=%d;MemWarningLevel=%d",$ParamVal,0.95*$ParamVal) ,
			   proxy_Aumsi_ProcessMem	  =>
    		     sprintf("MemTerminateLevel=%d;MemWarningLevel=%d",$ParamVal,0.95*$ParamVal) ,
    		   MaxMTSThreads	=>
    		     sprintf("MaxThreads=%d;MaxPdfThreads=%d",$ParamVal-1,1) ,
    		   PoolSize		=> "InitialIMAP4SessionPoolSize=$ParamVal" ,
			   Aumsi_ulimit => "##NullIgnore this Value=$ParamVal"
    		  );
    my %Result=();
    my ($Record,@KeyVal);
    
    unless ( defined $ParamRec{$ParamName} )
    {
    	WrLog("Warning\tUnknown Configuration parameter \"$ParamName\" Ignore this config parameter.");
    	return %Result;
    }

	

    foreach $Record ( split(/;/,$ParamRec{$ParamName}) )
    {
    	@KeyVal=split(/=/,$Record);
    	$Result{$KeyVal[0]}=$KeyVal[1];
    }
    return %Result;
}
	
sub setAumsi # Unit
{
    my $Unit=shift;
    my $Err=0;
    my $AumsiFile="/usr/cti/conf/aumsi/aumsi.conf";
    my %UnitList=( CAS	=> "NumOfConnections|NumOfThreads|PoolSize|Aumsi_ulimit" ,
    		   PROXY	=> "NumOfConnections|NumOfThreads|PoolSize|Aumsi_ulimit");
    unless ( defined $UnitList{$Unit} )
    {
    	WrLog("Info\tUnit \"$Unit\" should skip aumsi configuration...");
    	return ;
    }
    my @ParamList=split('\|',$UnitList{$Unit});
    my @SedList=();
    ## WrLog("-- Debug Hardware configuration for Aumsi..");
    foreach my $Iter (@ParamList)
    {
    	if ( defined $G_HWList{$Iter} )
    	{
    	   ## WrLog("-- Param $Iter is defined Vlaue = $G_HWList{$Iter}");
    	   my %Record = ParamsList($Iter,$G_HWList{$Iter});
    	   while ( my ($Param,$Val) = each(%Record) )
    	   {
    	   	push(@SedList,"\'/$Param/ s/=.*\$/=$Val/\'");
    	   }
    	   ## push(@SedList,"\'/$Iter/ s/=.+\$/=$G_HWList{$Iter}\'");
    	} else
    	{
    	   WrLog ("Info\tParameter \"$Iter\" NOT DEFINNED for this hardware use the default value (No Change will be done)");
    	}
    }
    if ( $#SedList >= 0  )
    {
    	my $Cmd=join(" -e ",@SedList);
    	my $Backup=BackupFile($AumsiFile);
    	unless  ( -e $Backup )
    	{
    	    WrLog("Error\tSkip Aumsi configuration due to error.");
    	    return 1;  
    	}
    	##WrLog("- Sed command: -e $Cmd $Backup > $AumsiFile");
    	$Err += RunCmds("sed -e $Cmd $Backup > $AumsiFile");
		#####  Fix For DR-0-191-961- Setting the file descriptor max limit per HW
		exists  $G_HWList{Aumsi_ulimit} or return $Err;
		$Err += RunCmds("perl -pi.backup -e '/ulimit.+n/ and s/\\d+/$G_HWList{Aumsi_ulimit}/' /usr/cti/aumsi/run_aumsi.sh")
    }else
    {
    	WrLog("Info\tNo Changes to aumsi configuration.");
    }
    return $Err;
}

sub setBabysitter # Unit
{
    my $Unit=shift;
    my $Err=0;
    my $Path="/usr/cti/conf/babysitter";
    my $Suffix="ServiceKit";
    my %FileMapping=( cas_Aumsi_ProcessMem	=> "ApplicationsAumsiLINUX.xml" ,
					proxy_Aumsi_ProcessMem	=> "ApplicationsAumsiLINUX.xml" ,
    		      Genesis_ProcessMem => "ApplicationsGenesis.xml" ,
				WebInbox_ProcessMem => "ApplicationsWebInbox.xml");
    my %UnitMapping=( CAS	=> "cas_Aumsi_ProcessMem;Genesis_ProcessMem;WebInbox_ProcessMem" ,
    		      PROXY	=> "proxy_Aumsi_ProcessMem"	);
    my @ParamList=split(/;/,$UnitMapping{$Unit}) ;
    my @SedList=();
    foreach my $Iter (@ParamList)
    {
    	if ( defined $G_HWList{$Iter} )
    	{
    	   ## WrLog("-- Param $Iter is defined Vlaue = $G_HWList{$Iter}");
    	   my %Record = ParamsList($Iter,$G_HWList{$Iter});
    	   while ( my ($Param,$Val) = each(%Record) )
    	   {
    	   	push(@SedList,"\'s/$Param=\"[^\"]*\"/$Param=\"$Val\"/\'");
    	   }
    	   if ( $#SedList >= 0  )
    	   {
    		my $Cmd=join(" -e ",@SedList);
    		my $AppFileName= "$Path/$FileMapping{$Iter}" ;
    		-e $AppFileName or $AppFileName .= ".$Suffix";
    		my $Backup=BackupFile($AppFileName);
    		unless  ( -e $Backup )
    		{
    	    		WrLog("Error\tSkip $FileMapping{$Iter} configuration due to error.");
    	    		$Err++;
    	    		next ;
    	    	}
    	    	## WrLog("- Sed command: -e $Cmd $Backup > $Path/$FileMapping{$Iter}"); 
    	    	$Err += RunCmds("sed -e $Cmd $Backup > $AppFileName");
    	    	@SedList=();
    	   }
    	}else
    	{
    	   WrLog ("Info\tParameter \"$Iter\" NOT DEFINNED for this hardware use the default value (No Change will be done)");
    	}
    }
    return $Err;
}



sub setCatalina
{
    my $Unit=shift;
    my $Err=0;
    my @FilesNames=("/usr/cti/genesis/JGlue/bin/catalina.sh",
					"/usr/cti/webinbox/WIS/bin/catalina.sh"	);
     
	   foreach my $FileName (@FilesNames)
    {

    unless ( $Unit =~ /CAS/ )
    {
    	return 0;
    }
    unless ( defined $G_HWList{JavaMem} )
    {
    	WrLog ("Info\tParametr \"JavaMem\" NOT DEFINNED for this hardware use the default value (No Change will be done)");
    	return 0;
    }
    my $Backup=BackupFile($FileName);
    unless  ( -e $Backup )
    {
    	 WrLog("Error\tSkip $FileName configuration due to error.");
    	 return 1;
    }
    my %Record= ParamsList("JavaMem",$G_HWList{JavaMem});
    ## WrLog("-- sed Command: sed \'/JAVA_OPTS/ s/\\(s\\|x\\)[0-9]*m/\\1$Record{JAVA_OPTS}m/g\' $Backup > $FileName");
    ## $Err=RunCmds("sed \'/JAVA_OPTS/ s/\\(s\\|x\\)[0-9]*m/\\1$Record{JAVA_OPTS}m/g\' $Backup > $FileName");
	$Err=RunCmds("perl -wnp -e '/JAVA_OPTS/ and s/(Xm(s|x))\\d+/\${1}$Record{JAVA_OPTS}/g' $Backup > $FileName");
   
	}
 return $Err;
}

sub setMTS
{
    my $Unit=shift;
    my $FileName="/usr/cti/conf/mts/config.xml";
    my @SedCmds=();
    my %UnitParams=( CAS	=> "MaxMTSThreads",
    		     PROXY	=> "MaxMTSThreads",
    		     "MTS-U"	=> "MaxMTSThreads" );
    
    unless ( defined $UnitParams{$Unit} )
    {
    	return 0;
    }
    WrLog("Info\tUpdate MTS Parameters");
    
    foreach my $Iter ( split(';',$UnitParams{$Unit}) )
    {
    	unless ( defined $G_HWList{$Iter} )
    	{
    	     WrLog("Info\tLeave Default value of $Iter");
    	     next;
    	}
    	my %Record= ParamsList($Iter,$G_HWList{$Iter});
    	while ( my ($Param,$Value) = each(%Record) )
    	{
    	    push(@SedCmds,"'/$Param/ s/>[^<]*</>$Value</'");
    	}
    }
    my $SedStr=join(" -e ",@SedCmds);
    #####  PSG00612758  Fix the Problem when there is no MTS configuration ....
    $SedStr or return 0;
    my $Backup=BackupFile($FileName);
    unless  ( -e $Backup )
    {
    	 WrLog("Error\tSkip $FileName configuration due to error.");
    	 return 1;
    }
    return RunCmds("sed -e $SedStr $Backup > $FileName");
}

sub SetupConntract  # Number of Contracts
{
    my $Unit=shift;
    my $Conntract=shift;
    unless ( $Unit =~ /CAS|PROXY/i )
    {
    	return 0;
    }
    my $FileName="/etc/modprobe.conf";
    my $Counter=0;
    my $Backup=BackupFile($FileName);
    
    unless  ( -e $Backup )
    {
    	 WrLog("Error\tSkip Setup IP Conntract configuration due to error.",
    	       "     - This may influence load performance (on the machines that balancer run).");
    	 return 1;
    }
    WrLog("INFO\tSetup IP conntract to $Conntract");
    return RunCmds("sed \'/ip_conntrack.*hashsize/ d\' $Backup > $FileName",
    		   "echo \"options ip_conntrack hashsize=$Conntract\" >> $FileName" );
}

sub setImfa
{
    my $Unit=shift;
    my $NumThreads=shift;
    unless ( $Unit =~ /PROXY/i )
    {
    	return 0;
    }
    my $FileName="/etc/nplex/imfa/settings/.data";
    my @ParamsList=("NumThreads");
    my @SedCmds=();
    my $Backup=BackupFile($FileName);
    
    unless  ( -e $Backup )
    {
    	 WrLog("Error\tFail to backup Imfa configuration.");
    	 return 0;
    }
    foreach my $Param (@ParamsList)
    {
    	defined $G_HWList{$Param} or next ;
    	WrLog("INFO\tSetup Parameter $Param in Imfa");
    	push (@SedCmds,"/$Param/ s/=.*\$/=$G_HWList{$Param}/");
    }
    unless ( $#SedCmds < 0 )
    {
    	my $SedExec=sprintf("sed -e \'%s\' $Backup > $FileName",join("\' -e \'",@SedCmds));
    	return RunCmds($SedExec);
    }
    WrLog("Info - No Configuration found for Imfa. leave defaut value at Imfa");
    return 0;
}

####################################################################
#	M A I N
####################################################################

my ($Machine,$ErrMessage);

ReadCLI();
$Machine=getHWType();
%G_HWList=getMachineConf($G_CLIParams{Conf},$Machine,$G_CLIParams{Unit});

if ( $G_ErrorCounter )
{
   EndProg(1,"Fatal\tSkip script due to errors.",
   	     "     \tSee log file \"$G_CLIParams{LogFile}\" for details.");
}
if ( defined $G_HWList{MaxIP_conntrack} )
{
   $G_ErrorCounter += SetupConntract($G_CLIParams{Unit},$G_HWList{MaxIP_conntrack});
}

$G_ErrorCounter += setAumsi($G_CLIParams{Unit});
$G_ErrorCounter += setBabysitter($G_CLIParams{Unit});
$G_ErrorCounter += setMTS($G_CLIParams{Unit});
$G_ErrorCounter += setImfa($G_CLIParams{Unit});
$G_ErrorCounter += setCatalina($G_CLIParams{Unit});
$ErrMessage= $G_ErrorCounter ? " -= Finish with ERRORS !!! see log file \"$G_CLIParams{LogFile}\" =-" 
		: "Finish successfully";
EndProg($G_ErrorCounter,$ErrMessage);

