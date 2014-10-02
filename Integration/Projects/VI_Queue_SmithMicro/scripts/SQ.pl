#!/usr/bin/perl

use strict;
use threads ;


#########################################################
#  Global variables
#########################################################

my $G_ErrorCounter=0;
my $G_MTArunDir="/opt/criticalpath/global/bin" ;
my $G_RecSep=";";
my %G_CLIParams=(  LogFile  => "-" ,
		   MTAPass  => "MT#adm_iN" ,
		   Domains	=> "All" ,
		   Answer   => "/usr/cti/conf/ServiceKit/MTAQueue.conf");
my %G_Share;		   

sub usage
{
    $0 =~ s/^.+[\\\/]// ;
    my @Description= (
"The following scripts start / stop SMTP queue messages." ,
"this is done by changing the SMTP route rules." ,
"usage:" ,
"$0 OPEATION MACHINE [OPTIONS]" ,
"OPERATIN :",
"  -q " ,
"  	start SMTP message queue" ,
"  -uq" ,
"  	stop SMTP message queue. this will enable sending SMTP messages." ,
"  -Stat",
"	display the queue state." ,
"" ,  	
"MACHINE",
"   -all",
"   	This will start / stop queue on all the proxies ( all the proxies that this procedure",
"   	install on them ). to verify which proxies will be affected from this type SQ.pl -help." ,
"   -IP iplist",
"   	This will start / stop queue on all iplist machines. iplist should be list of ips separated" ,
"   	with comma." ,
"   	example: SQ.pl -q -IP 1.2.3.4,10.20.5.1",
"   	this will start queuing SMTP messages on machines 1.2.3.4 and 10.20.5.1",
"OPTIONS",
"   -MTAPass password" ,
"   	MTA Management password. this will used \"password\" to enter MTA configuration." ,
"   -Answer filename" ,
"   	Configuration file. This script use configuration file to change the MTA routing rules." ,
"   	This optional parameter will use filename to configure the MTA. for MTA configuration file",
"   	syntax contact Comverse Technical support." ,
"   -LogFile filename",
"   	all the logs of this script will be write to filename." ,
"   -Domain  Dmain list ",
"			list of domains to quese/unqueue Default is All"
    );
    foreach (@Description) {print "$_\n" ;}
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
   my @Lines=@_;
   my $TSize=70;
   my $Ch_Title="*";
   my $Border=$Ch_Title x ($TSize + 4);
   
   WrLog($Border);
   foreach  (@Lines)
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
     unless ( $#_ < 0 ) {WrLog(@_);}
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
    my (@Lines,$Iter,$Definition,$Key,$InstNo,$Val,$PIndx);
    my %Result=();
    
    foreach $Iter (@Input)
    {
    	@Lines=split($G_RecSep,$Iter);
    	foreach $Definition (@Lines)
    	{
    	      if ( $Definition =~ m/([^=]+)=(.+)/ )
    	      {
		 $Key=$1;
		 $Val=$2;
		 $InstNo=1;
		 $PIndx=$Key;
		 while ( defined $Result{$PIndx} )
		 {
		 	$PIndx="$Key#$InstNo";
		 	$InstNo++;
		 }
    	      	 $Result{$PIndx}=$Val;
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

sub IsMTAup
###############################################################################
#
# Input:	[$StartifDown]
#
# Return:	 1 (true) if MTA is up, 0 - if it down
#
# Description:	check if MTA process is up.
#
###############################################################################
{
   my $Startup=shift;
   my $MTAPort=4200;
   my ($Err,$ChkCounter,$Result);
   my $ChkCmd="netstat -na | grep LISTEN | grep $MTAPort";
   
   
   ### Test if MTA is up  ###
   $Result = system($ChkCmd) ? 0 : 1 ;
   
   if ( ! $Result and $Startup )
   {
   ##  Start MTA Proccess
      my $SMTP_USER_ID=`sed -n '/ServerUserID/ s/.*=//p' /etc/nplex/.data` ;
      chomp ($SMTP_USER_ID);
      my $SMTP_User=$SMTP_USER_ID eq "" ? "" : `sed -n "/$SMTP_USER_ID/ s/:.*//p" /etc/passwd` ;
      chomp ($SMTP_User);
      $ChkCmd=$SMTP_User ? "$G_MTArunDir/su_mips.sh $SMTP_User smtpd start": "$G_MTArunDir/smtpd -start";
      if ( system($ChkCmd) )
      {
      	  WrLog("Error - Fatal error during MTA Start up.",
      	  	"      + Try to start smtpd with command \"$ChkCmd\"");
      	  return 0;
      }
      $ChkCounter=10;
      while ( ! $Result and $ChkCounter )
      {
      	  $Result = IsMTAup();
      	  $ChkCounter-- ;
      	  WrLog("Info\tWait smtpd process to startup.");
      	  sleep 5;
      }
   }
   return $Result;
}

sub CleanThread #\%LogsMap->[mgrlog,serverip],\@FailMTA,\@Success
{
    my $LogsMap=shift;
    my $FailMTA=shift;
    my $Success=shift;
    my $Err=0;
    my (@LogLines,@Output);
    
    foreach my $Iter (threads->list())
    {
    	### TODO - find how to read trade state ###
    	my $Record=$$LogsMap{$Iter->tid()};
    	### Check if process finish by checking the log of mgr .... #
    	-e $$Record[0] or next;
    	system("tail -1 $$Record[0] | grep -i Finish") and next;
    	@Output=$Iter->join();
    }
    my @Result=threads->list();
    ## WrLog("Debug Number of Threads $#Result , ");
    return $#Result + 1;
}

sub RunThread
{
    my $Cmd=shift;
    my $FileName=shift;
    my $Flag;
    my $Thd=threads->self();
    my @OutPut=`$Cmd 2>&1`;
    my $Err=$?;
    while ( ($Flag=$?) != 0 ){ system("echo Clean Error $?");}
    if ( $Err )
    {
    	my @Lines= -e $FileName ? ReadFile($FileName) : () ;
    	push(@Lines,"ERROR - mgr return Error $Err:","Execute: $Cmd",@OutPut);
    	WriteFile($FileName,@Lines,"Finish Log File $FileName");
    }
    system("echo \"Finish Log File $FileName\" >> $FileName");
    unshift(@OutPut,"Execute: $Cmd");
    printf " Debug --- Thread %d has finished !!!\n",$Thd->tid(); 
    return @OutPut;
}

sub getConfRep # \%Rec 
{
    my $RecPoint=shift;
    my ($Err,@FailMTA,@Success);
    foreach my $ListPoint ( values (%$RecPoint) )
    {
    	my @LogLines=ReadFile($$ListPoint[0]);
    	###  Analyze the Log  ( check if configuration success) ######
    	$Err=0;
    	foreach (@LogLines)
    	{
    	     $_ =~ /^ERROR/ or next;
    	     $Err=1;
    	     push(@FailMTA,"Log of $$ListPoint[1]:",'-' x 60,@LogLines,'=' x 60,"");
    	     $G_ErrorCounter++;
    	     ##WrLog("Error - Fail to configure/set $$Record[1] :"," -\t$_");
    	     last ;
    	}   	
    	$Err or push(@Success,sprintf("%-17s Configured successfully",$$ListPoint[1]));
    }
    PrnTitle("List of Successful configured MTAs:",@Success);
    WrLog("Info - List of failed MTAs:",@FailMTA);
    return $#FailMTA < 0 ? 0 : 1 ;
}

sub getMonitor #%Rec
{
    my $RecPoint=shift;
    my ($Err,@FailMTA,@Success,@Status);
    foreach my $ListPoint ( values (%$RecPoint) )
    {
    	push(@Success,"MTA $$ListPoint[1] Status:");
    	@Status=("Fail to query MTA","Error");
    	my @LogLines=ReadFile($$ListPoint[0]);
    	###  Analyze the Log  ( check if configuration success) ######
    	foreach my $Line (@LogLines)
    	{
    	     if ( $Line =~ /OK/ )
    	     {
    	     	push(@Success,sprintf("Domain: %-19s - $Status[1]",$Status[0]));
    	     } elsif ( $Line =~ /REMOTE(\s+(\S+)){2}/ )
    	     {
    	     	@Status=($2,"Normal Operation (NON Queue Mode)");
    	     } elsif ( $Line =~ /SMTP\s+(\S+)/ )
    	     {
    	     	my $TmpIP=$1;
    	     	$TmpIP == "127.0.0.1" and $Status[1]="Queue Mode";
    	     } elsif ($Line =~ /ERROR/)
    	     {
    	     	push(@Success,sprintf("Domain: %-19s - Error:",$Status[0]),$Line);
    	     }
    	}
    	push(@Success,'-' x 60,"");
    	$Err=0;
    }
    PrnTitle("MTA Queuing Status:",@Success);
    ##WrLog("Info - List of failed MTAs:",@FailMTA);
    return 0 ;
}


sub RunMgr 
###############################################################################
#
# Input:	\@IPs, @List of Mgr commands , 
#
# Return:	0 - O.K , 1- Error occurred
#
# Description:  Execute Batch of MGR commands.
#
###############################################################################
{
    my $IpPoint=shift;
    my @MgrCmds=@_;
    my $MgrCmdFile="/tmp/MgrCommands.txt";
    my $MgrLog="/tmp/MgrLog.log";
    my $MgrExc="$G_MTArunDir/mgr -w \'$G_CLIParams{MTAPass}\' -e $MgrCmdFile  -q" ;
    my $MaxThreads=100;
    my $Err=0;
    my (@Success,@FailMTA,@LogLines,@MgrThredas,%LogsMap,$NumThreads);
    
    RunCmds("rm -f $MgrCmdFile");
    WriteFile($MgrCmdFile,@MgrCmds) and EndProg(1,"Fatal - Fail to save temporary commands file \"$MgrCmdFile\"");
    foreach my $ServerIP (@$IpPoint)
    {
    	push(@MgrThredas,"rm -f $MgrLog" . "_$ServerIP");
    }
	WrLog("Info - Clean Old Files (if exist)");

    RunCmds(@MgrThredas);
    foreach my $ServerIP (@$IpPoint)
    {
    	while ( ($NumThreads=CleanThread(\%LogsMap,\@FailMTA,\@Success,1)) >= $MaxThreads )
    	{
    	     WrLog("Info - Script is using Maximum Threads Resource ($MaxThreads) , used $NumThreads");
    	     sleep(30);
    	}  
    	WrLog("Info - Access to $ServerIP ...");
    	my $LogFile=$MgrLog . "_$ServerIP";
    	my $ThreadRec=threads->create(\&RunThread,"$MgrExc -s $ServerIP -f $LogFile",$LogFile,\%G_Share);
    	## WrLog(sprintf("Debug - Map Index is %d" ,$ThreadRec->tid()));
    	$LogsMap{$ThreadRec->tid()}=[$LogFile,$ServerIP];
   }
   while ( ($NumThreads=CleanThread(\%LogsMap,\@FailMTA,\@Success)) > 0 )
   {
   	WrLog("Info - wait for Process Termination ($NumThreads)...");
   	sleep(5);
   }
   ## PrnTitle("List of Successful configured MTAs:",@Success);
   ## WrLog("Info - List of failed MTAs:",@FailMTA);
   ## return $Err;
   return \%LogsMap;
}

sub ReadList # 
###############################################################################
#
# Input:	$ListType - String of mgr Command. [$IP]
#
# Return:
#
# Description:  Read List configuration (List of domains list of users etc ..
#
###############################################################################
{
    my $ListType=shift;
    my $MTAIP=shift;
    my $MgrExc="$G_MTArunDir/mgr -w \'$G_CLIParams{MTAPass}\'" . (length($MTAIP) > 0 ? " -s $MTAIP" : " ") ; ## $ListType LIST" ;
    
    
    unless ( length($MTAIP) > 0 or IsMTAup("StartMTA") )
    {
    	WrLog("Error\tSkip mgr configuration - MTA is down.");
    	return "";
    }
    
    my @List=`$MgrExc $ListType LIST`;
    chomp @List;
    my $Status=pop(@List);
    unless ( $Status =~ /OK/i )
    {
    	WrLog("Error - Fail to get List \"$ListType\"","Execute: $MgrExc $ListType LIST",@List,"");
    	return "";
    }
    for ( my $i=0 ; $i <= $#List ; $i++ )
    {
    	##  Clear The First * in the Answer ##
    	$List[$i] =~ s/\*\s+// ;
    	### if there is * at the line put " example: ALLOW * -> ALLOW "*" ###
    	$List[$i] =~ s/(\s)(\*+)(\s|$)/$1\"$2\"$3/ ;
    }
    return @List;
}

sub AddRelayRule
###############################################################################
#
# Input:	$Relay - format domain via host [port]
#
# Return:
#
# Description:
#
###############################################################################
{
   my $Input=shift;
   my $QueueHost="127.0.0.1";
   my $QueuePort=1234;
   unless ( $Input =~ /(\S+)\s+via\s+(\S+)(\s+([0-9]+))?/ )
   {
   	WrLog("Error - RelayRule format error \"$Input\"");
   	return  1;
   }
   my $Domain=$1;
   my $Host= defined $G_CLIParams{"q"} ? $QueueHost : $2;
   my $Port=defined $G_CLIParams{"q"} ? $QueuePort : $4 ;
   my @MgrCmds=("REMOTE DOMAIN ADD $Domain",
   		"REMOTE ROUTE $Domain ADD $Host PORT=$Port"); 
   $Port > 0 or $MgrCmds[1] =~ s/=.*$/=50025/ ;
   return  @MgrCmds;
}

sub GetIPMask # Number
###############################################################################
#
# Input:	Number  0-32
#
# Return:
#
# Description:  Convert Integer Number to Mask formt (255.255.....) 
#
###############################################################################
{
    my $MaskNum=shift;
    my $Result="";
    my ($Octet,$Bit,$Byte);
    
    if ( $MaskNum < 0 or $MaskNum > 32 )
    {
    	$G_ErrorCounter++;
    	return $MaskNum;
    }
    
    for ( $Octet=0 ; $Octet < 4 ; $Octet++ )
    {
    	$Bit = $MaskNum > 8 ? 8 : $MaskNum ;
    	$Byte = 256 - 2 ** (8 - $Bit);
    	$Result .= $Result eq "" ? "$Byte" : ".$Byte";
    	$MaskNum -= $MaskNum> 8 ? 8 : $MaskNum;
    }
    return $Result;
}

sub AddAccessRule
###############################################################################
#
# Input:	IP or subnet 
#
# Return:
#
# Description:  Add Authentication + Relay Allow Rule 
#
###############################################################################
{
    my $Input=shift;
    my @AccessList=split(',',$Input);
    my @CmdList=();
    my $Err=0;
    
    foreach my $Request (@AccessList)
    {
    	### Check if Access Rule is IP or domain ####
    	if ( $Request =~ /([0-9]+\.){3}[0-9]/ )
    	{
    	    $Request =~ s/[-\/]/ / ;
    	    if ( $Request =~ s/\s([0-9]+)\s*$/ / )
    	    {
    	    	$Err=$G_ErrorCounter;
    	    	$Request .= GetIPMask($1);
    	    	unless ( $Err == $G_ErrorCounter )
    	    	{
    	    	    WrLog("Error - Incorrect Access Rule Syntax:\"$Request\". skip this Rule configuration.");
    	    	    next;
    	    	}
    	    }
    	}
    	push(@CmdList,"ACCESS AUTHENTICATION ALLOW $Request",
    		"ACCESS RELAY ALLOW $Request" );
    }
    return @CmdList;
}

sub AddManagerAccess
###############################################################################
#
# Input:	IP or subnet 
#
# Return:	mgr command
#
# Description:  Add Manager Access to MTA/MIps
#
###############################################################################
{
    my $Input=shift;
    $Input =~ s/[-\/]/ / ;
    return "ACCESS MANAGER ALLOW $Input";
}

sub AddFiltter
###############################################################################
#
# Input:	@List of Filters
#
# Return:
#
# Description:  Write List of Filters ... 
#
###############################################################################
{
    my $Input=shift;
    my @Filters=split(',',$Input);
    my @Content=ReadList("DOMAIN FILTER \"*\" GET");
    my %NewFilters=();
    my $Err;
    
    foreach my $Filter (@Filters)
    {
    	unless ( $Filter =~ /LBL.+?\"(.+)\"/ )
    	{
    	    WrLog("Error - Wrong Filter definition at configuration file.",
    	          "      + \"$Filter\"");
    	    return 1;
    	}
    	$Input=$1 , $Err=$G_ErrorCounter;
    	$Filter =~ s/(IP-RELAY.+)[\/-\s]+([0-9]+)\s*$/$1/ and $Filter .= ("/" . GetIPMask($2) );
    	unless ( $Err == $G_ErrorCounter )
    	{
    	    WrLog("Error - Illegal Filter Syntax \"$Filter\". Skip Filter configuration");
    	    next;
    	}
    	###  Fix Filters Syntax  #####
    	$Filter =~ /IP-RELAY/ and $Filter =~ s/(\.[0-9]+)[-\s]([0-9]+\.)/$1\/$2/ ;
    	$NewFilters{$Input}=$Filter;
    }
    
    for (my $LineNo=0 ; $LineNo <= $#Content ; $LineNo++ )
    {
    	if ( $Content[$LineNo] =~ /LBL.+?\"(.+)\"/ and defined $NewFilters{$1} )
    	{
    	    $Content[$LineNo]=$NewFilters{$1};
    	    delete $NewFilters{$1};
    	}
    }
    my $LastFilter=pop(@Content);
    while ( my ($Trash,$Filter) =  each(%NewFilters) )
    {
    	push(@Content,$Filter);
    }
    push(@Content,$LastFilter);
    unshift(@Content,"DOMAIN FILTER \"*\" SET");
    push(@Content,".");
    return @Content;
}

sub NotReadyYet
{
    WrLog("Debug - This parameter is not supported yet. ( latter ).",
    	  "      + Parameter value [input to function] : @_");
}

sub SetMTAPassword
{
    $G_CLIParams{MTAPass}=shift;
    return 0;
}

sub AddUser
###############################################################################
#
# Input:    	$User - format user@domain password
#
# Return:
#
# Description:
#
###############################################################################
{
   my $Input=shift;
   my ($User,$Domain,$Password);

   unless ( $Input =~ /(\S+?)@(\S+)\s+(\S+)/ )
   {
      WrLog("Error\tAddUser Value format error \"$Input\"",
      	    "     \t- The format should be \"user\@mail.domain password\"");
      return 1;
   }
   $User=$1;
   $Domain=$2;
   $Password=$3;
   return ("DOMAIN ADD $Domain","USER $Domain ADD $User CPASS=$Password",
   	   "DOMAIN administrator $Domain ADD $User GAM=1536");
}

sub AddMTAParam #$Parametr , $Value
{
    my $Parameter=shift;
    my $PValue=shift;
    return "SET $Parameter $PValue";
}

sub RunMTACmd # Full String
{
    my $MTACmd=shift;
    return $MTACmd;
}

sub RunClear
{
    my @ClearTypes=split(',',shift);
    my $Local=shift;
    my @AccesList;
    my %TypeList = (accessrelay	=> "ACCESS RELAY:ACCESS RELAY REMOVE" ,
    		    accessauth  => "ACCESS AUTHENTICATION:ACCESS AUTHENTICATION REMOVE" ,
    		    routedomain	=> "REMOTE DOMAIN:REMOTE ROUTE #Replace#" ) ;
    my $Err=0;
    my @Result=();
    foreach my $ClearTyp (@ClearTypes)
    {
    	 my $Extra=$ClearTyp =~ s/\s+(.+)$// ? $1 : "" ;
    	 my @mgrcmds=split(':',$TypeList{lc($ClearTyp)});
    	 
    	 @AccesList=length($Extra) > 0 ? split(/\s+/,$Extra) : ReadList($mgrcmds[0],$Local);
    	 ## WrLog("Debug - Clear List Type $ClearTyp");
    	 foreach my $Iter (@AccesList)
    	 {
    	      my $Cmd=$mgrcmds[1];
    	      $Cmd=~ s/#Replace#/$Iter CLEAR/ or $Cmd .= " $Iter" ; 
    	      push(@Result,"$Cmd");
    	 }
    }
    return @Result;
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
   	WrLog("Error - Fail to read Configuration file $File");
   	return 1;
   }
   foreach $Line ( @Content )
   {
   	$Line =~ /^\s*#/ and next ;
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
   	unless ( $Line =~ /.=./ )
   	{
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
# Description: Write the @Content Lines into $FileName (override the file).
#
###############################################################################
{
   my $FileName=shift;
   my @Lines=@_;
   my $Err=0;
   my $Single;
 
   WrLog("Info\tRewriting file $FileName.");
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
   if ( $Err )
   {
   	WrLog("Error\tFail to write file $FileName");
   }
   return $Err;
}

sub BuildCmds
###############################################################################
#
# Input:        \%Conf	
#
# Return:	0 - for O.K != for Errors
#
# Description:  Build Command file for mgr according to \%Conf 
#
###############################################################################
{
   my $ConfP=shift;
   my $MTAIp=shift;
   my @Result=();
   my %Func=( RelayRule		=> \&AddRelayRule ,
	   DefaultFilter	=> \&AddFiltter ,
	   ExternalMTA		=> \&NotReadyYet ,
	   AllowDomains		=> \&AddAccessRule ,
	   AllowIPs		=> \&AddAccessRule ,
	   ManagerPassword	=> \&SetMTAPassword ,
	   AllowManagerIPs	=> \&AddManagerAccess ,
	   AddUser		=> \&AddUser  ,
	   Cmd			=> \&RunMTACmd ,
	   Clear		=> \&RunClear);
   
   ## Update Password First  ##
   exists $$ConfP{ManagerPassword} and SetMTAPassword($$ConfP{ManagerPassword});
   delete $$ConfP{ManagerPassword};
   
   ##   Clear First  ####
   my @ClearList = grep(/Clear/,keys(%$ConfP));
   foreach my $Iter (@ClearList)
   {
    	push(@Result,RunClear($$ConfP{$Iter},$MTAIp));
    	delete $$ConfP{$Iter};
   }

   while ( my ($Param,$PValue) = each(%$ConfP) )
   {
      ### If there are multi instance of same parameter
      $Param =~ s/#[0-9]+$// ;	
      my $FuncName=defined $Func{$Param} ? $Func{$Param} : \&AddMTAParam;
      push(@Result,defined $Func{$Param} ? $FuncName->($PValue) : $FuncName->($Param,$PValue)) ;
      ## WrLog("-- Debug ConfCommad=$Param -> Mgr:",$Result[-1],"");
   }
   return @Result;
}

sub getFarmIPs
{
    my $FarmName=shift;
    my $BalancerConf="/usr/cti/conf/balancer/balancer.conf";
    my @Content=ReadFile($BalancerConf);
    my @Result=();
    
    foreach (@Content)
    {
    	/$FarmName/.../\[.+\]/ or next;
    	/Server.+=(.+?),/i or next;
    	push(@Result,$1);
    }
    return @Result;
}

sub CheckQueue #\%Config,@Ips
{
    my $Point=shift;
    my @Ips=@_;
    my @Domains;
    my $MgrCmd="/tmp/MgrCmds.txt";
    my @Result;
    
    ##WrLog("Debug - Start Build monitoring commands ....");
    while ( my ($Param,$PVal) = each(%$Point) )
    {
    	### WrLog("Debug - Update Domains:$Param,$PVal");
    	$Param =~ /RelayRule/ or next;
    	$PVal =~ /(\S+)\s+via/ or next;
    	##push(@Domains,$1);
    	push(@Domains,"REMOTE ROUTE $1 LIST");
    	
    }
    return @Domains;
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
    my @MustParam=("Answer");
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
    	    	return -1;
    	    	usage();
    	    	EndProg();
    	    }
    	} else
    	{
    	    push(@ParamValue,$Iter);
    	}
    }
    $G_CLIParams{$ParamName}=join(',',@ParamValue);
    foreach ( @MustParam )
    {
    	unless ( defined $G_CLIParams{$_} )
    	{
    	    WrLog("Error - missing parameter \"$_\"");
    	    $Err++;
    	}
    }
    return $Err;
}

############################################################################################
#
#   					M A I N
#
############################################################################################

$G_ErrorCounter=ReadCLI();
my $Message= exists $G_CLIParams{"q"} ? "Start Queuing messages. This will stop SMTP delivery." :
	"Stop Queuing messages. This will enable SMTP Delivery.";
WrLog("Info - " . $Message);
my %MTACustom=ReadConfig($G_CLIParams{Answer});
if ( $G_ErrorCounter )
{
    usage();
    defined $MTACustom{IpList} and WrLog("List of MTA IPs:",split(',',$MTACustom{IpList}));
    EndProg(1);
}
my %FuncPoint = ( "q"	=>	[\&BuildCmds ,\&getConfRep] ,
		  "uq"	=>	[\&BuildCmds ,\&getConfRep] ,
		  "Stat" => 	[\&CheckQueue,\&getMonitor] );
### Validate Command Line #####
### my $MTAListStr= exists $G_CLIParams{all} ? $MTACustom{IpList} : $G_CLIParams{IP} ;

## my @MTAListIp=exists $G_CLIParams{all} ? getFarmIPs("MTS.DMZ.SITE") : split(/,/,$G_CLIParams{IP});

my @MTAListIp= split(/,/,exists $G_CLIParams{all} ? $MTACustom{IpList} : $G_CLIParams{IP});
if ( $#MTAListIp < 0  )
{
    WrLog("Error - Missing MTA List definition (use -all or -IP) see usage:");
    usage();
    EndProg(1);
}
my $CmdLine;
foreach my $CLi ( keys(%FuncPoint) )
{
	exists $G_CLIParams{$CLi} or next;
	$CmdLine = $CLi ;
	last;
}

unless ( defined $CmdLine )
{
    
    unless ( exists $G_CLIParams{"Stat"} )
    {
    	WrLog("Error - missing operation command ( use -q or -uq ). see usage:");
    	usage();
    	$G_ErrorCounter++;
    } else 
    {
    	$G_ErrorCounter += CheckQueue(\%MTACustom,@MTAListIp);
    }
    EndProg($G_ErrorCounter);
}
	   
delete $MTACustom{IpList};
my @Func=@{$FuncPoint{$CmdLine}} ;
## my @CmdList=BuildCmds(\%MTACustom,@MTAListIp);
## WrLog("Debugggggg -   Domains List is $G_CLIParams{Domains}");
unless ( $G_CLIParams{Domains} =~ /All/i )
{
	my @DomainList=split(/,/,$G_CLIParams{Domains});
	#WrLog("Debugggggg -   Domains for Exec:",@DomainList,"","","");
	while ( my($LineKey,$LineVal) = each(%MTACustom) )
	{
		##WrLog("Debbbbbbbug - $LineKey: \"$LineVal\"");
		my $Flag=0;
		$LineKey =~ /RelayRule/ and $LineVal =~ /(\S+)\s+via/ and $Flag=$1 ;
		$LineKey =~ /Clear/ and $LineVal =~ /(\S+)\s*$/ and $Flag=$1 ;
		$Flag or next;
		## WrLog("Debug - Searching Domain $Flag at List Domains");
		grep (/^$Flag$/,@DomainList) and next;
		## WrLog("Debug - Domain $Flag is NOT Part of :" , @DomainList,"");
		delete $MTACustom{$LineKey};
	}
}
my @CmdList=$Func[0]->(\%MTACustom,@MTAListIp);
## WrLog("Debug - CmdList:",@CmdList);
my $Point = RunMgr(\@MTAListIp,@CmdList);
$G_ErrorCounter += $Func[1]->($Point);
$Message = $G_ErrorCounter ? "-- End with Errors !! --" : "-- ## Finish successfully ## --";
EndProg($G_ErrorCounter,$Message);
