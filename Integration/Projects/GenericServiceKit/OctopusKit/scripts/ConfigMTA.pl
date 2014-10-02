#!/usr/bin/perl

use strict;
#########################################################
#  Global variables
#########################################################

my $G_ErrorCounter=0;
my $G_MTArunDir="/opt/criticalpath/global/bin" ;
my $G_RecSep=";";
my %G_CLIParams=(  LogFile  => "-" ,
		   MTAPass  => "A25Trk7B43" );

sub usage
{
    $0 =~ s/^.+[\\\/]// ;
    print "$0 [-LogFile FileName] [-MTAPass password] [-Answer FileName]\n";
    print "Description:\n";
    print "-----------------------------------------------------------\n";
    print "This script configure MTA acording to answer file.\n"; 
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
# Description:	check if MTA proccess is up.
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
      	  WrLog("Info\tWait smtpd proccess to startup.");
      	  sleep 5;
      }
   }
   return $Result;
}

sub RunMgr 
###############################################################################
#
# Input:	@List of Mgr commands
#
# Return:	0 - O.K , 1- Error occurred
#
# Description:  Excute Batch of MGR commands.
#
###############################################################################
{
    my @MgrCmds=@_;
    my $MgrCmdFile="/tmp/MgrCommands.txt";
    my $MgrLog="/tmp/MgrLog.log";
    my $MgrExc="$G_MTArunDir/mgr -w \'$G_CLIParams{MTAPass}\' -e $MgrCmdFile -f $MgrLog -q" ;
    my $Err=0;
    
    unless ( IsMTAup("StartMTA") )
    {
    	WrLog("Error\tSkip mgr configuration - MTA is down.");
    	return 1;
    }
    RunCmds("rm -f $MgrCmdFile");
    WriteFile($MgrCmdFile,@MgrCmds) and EndProg(1,"Fatal - Fail to save temporary commands file \"$MgrCmdFile\"");
    RunCmds("$MgrExc") and EndProg(1,"Fatal - Fail to run Mgr Command");
    my @LogLines=ReadFile($MgrLog);
    my @ErrMsg=();
    foreach (@LogLines)
    {
    	push(@ErrMsg," + $_");
    	$_ =~ /OK/ and @ErrMsg=() and next;
    	if ( $_ =~ /^ERROR/ )
    	{
    	   $Err++;
    	   WrLog("Error: Fail to Run mgr command:",@ErrMsg,"\t+ for more details see log file \"$MgrLog\"");
    	}
    }
   return $Err;
}

sub ReadList # 
###############################################################################
#
# Input:	$ListType - String of mgr Command.
#
# Return:
#
# Description:  Read List configuration (List of domains list of users etc ..
#
###############################################################################
{
    my $ListType=shift;
    my $MgrExc="$G_MTArunDir/mgr -w \'$G_CLIParams{MTAPass}\' $ListType LIST" ;
    
    unless ( IsMTAup("StartMTA") )
    {
    	WrLog("Error\tSkip mgr configuration - MTA is down.");
    	return "";
    }
    
    my @List=`$MgrExc`;
    chomp @List;
    my $Status=pop(@List);
    unless ( $Status =~ /OK/i )
    {
    	WrLog("Error - Fail to get List \"$ListType\"");
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
   unless ( $Input =~ /(\S+)\s+via\s+(\S+)(\s+([0-9]+))?/ )
   {
   	WrLog("Error - RelayRule format error \"$Input\"");
   	return  1;
   }
   my $Domain=$1;
   my $Host=$2;
   my $Port=$4;
   my @MgrCmds=("REMOTE DOMAIN ADD $Domain",
   		"REMOTE ROUTE $Domain ADD $Host PORT=$Port"); 
   if ( $Port <= 0 )
   {
   	$MgrCmds[1] =~ s/=.$/=50025/ ;
   }
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
    	    	    WrLog("Error - Incoreect Access Rule Syntax:\"$Request\". skip this Rule configuration.");
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
    	    WrLog("Error - Ilegal Filter Syntax \"$Filter\". Skip Filter configuration");
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
    my %TypeList = (accessrelay	=> "ACCESS RELAY:ACCESS RELAY REMOVE" ,
    		    accessauth  => "ACCESS AUTHENTICATION:ACCESS AUTHENTICATION REMOVE" ) ;
    my $Err=0;
    my @Result=();
    foreach my $ClearTyp (@ClearTypes)
    ## if ( $ClearType =~ /Access/i )
    {
    	 WrLog("Debug - Clear List Type $ClearTyp");
    	 my @mgrcmds=split(':',$TypeList{lc($ClearTyp)});
    	 my @AccesList=ReadList($mgrcmds[0] );
    	 foreach my $Iter (@AccesList)
    	 {
    	      push(@Result,"$mgrcmds[1] $Iter");
    	      ##$Err=RunMgr("$mgrcmds[1] $Iter");
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
   	EndProg(1,"Error - Fail to read Configuration file $File");
   }
   foreach $Line ( @Content )
   {
   	$Line =~ s/#.*$// ;
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
# Description: Write the @Content Lines into $FileName (overite the file).
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

if ( ReadCLI() )
{
    usage();
    EndProg(1);
}
my %Func=( RelayRule		=> \&AddRelayRule ,
	   DefaultFilter	=> \&AddFiltter ,
	   ExternalMTA		=> \&NotReadyYet ,
	   AllowDomains		=> \&AddAccessRule ,
	   AllowIPs		=> \&AddAccessRule ,
	   ManagerPassword	=> \&NotReadyYet ,
	   AllowManagerIPs	=> \&AddManagerAccess ,
	   AddUser		=> \&AddUser  ,
	   Cmd			=> \&RunMTACmd ,
	   Clear		=> \&RunClear);
	   
my $Err=$G_ErrorCounter;
my %MTACustom=ReadConfig($G_CLIParams{Answer});
if ( $Err != $G_ErrorCounter )
{
   EndProg(1,"Fatal - Fail to read answer file \"$G_CLIParams{Answer}\". Skip MTA configuration.");
}
my @CmdList=();
##   Clear First  ####
my @ClearList = grep(/Clear/,keys(%MTACustom));
foreach my $Iter (@ClearList)
{
    push(@CmdList,RunClear($MTACustom{$Iter}));
    delete $MTACustom{$Iter};
}

while ( my ($Param,$PValue) = each(%MTACustom) )
{
      ### If there are multi instance of same parameter
      $Param =~ s/#[0-9]+$// ;	
      my $FuncName=defined $Func{$Param} ? $Func{$Param} : \&AddMTAParam;
      push(@CmdList,defined $Func{$Param} ? $FuncName->($PValue) : $FuncName->($Param,$PValue)) ;
      ##WrLog("-- Debug ConfCommad=$Param -> Mgr:",@CmdList);
}
$G_ErrorCounter += RunMgr(@CmdList);
my $Message = $G_ErrorCounter ? "-- End with Errors !! --" : "-- ## Finish successfuly ## --";
EndProg($G_ErrorCounter,$Message);