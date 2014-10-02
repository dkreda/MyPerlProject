#!/usr/bin/perl

use strict;
#########################################################
#  Global variables
#########################################################

my $G_ErrorCounter=0;
my $G_MTArunDir="/opt/criticalpath/global/bin" ;
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
   
   if ( $Startup )
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
      while ( $ChkCounter )
      {
      	  $Result = IsMTAup();
      	  $ChkCounter -= $Result ? 1 : $ChkCounter;
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
# Description:
#
###############################################################################
{
    my $MgrExc="$G_MTArunDir/mgr -w $G_CLIParams{MTAPass}" ;
    my @MgrCmds=shift;
    my $Err=0;
    
    unless ( IsMTAup("StartMTA") )
    {
    	WrLog("Error\tSkip mgr configuration - MTA is down.");
    	return 1;
    }
    
    foreach ( @MgrCmds )
    {
    	$Err += RunCmds("$MgrExc $_");
    	if ( $Err )
    	{
    	   WrLog("Error\tmgr command Failed skip last mta configuration.");
    	   last;
    	}
    }
    return $Err;
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
   my $Port=$3;
   my @MgrCmds=("REMOTE DOMAIN ADD $Domain",
   		"REMOTE ROUTE $Domain ADD $Host PORT=$Port"); 
   if ( $Port <= 0 )
   {
   	$MgrCmds[1] =~ s/=.$/=50025/ ;
   }
   return  RunMgr(@MgrCmds);
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
    $Input =~ s/[-\/]/ / ;
    return RunMgr("ACCESS AUTHENTICATION ALLOW $Input","ACCESS RELAY ALLOW $Input");
}

sub AddManagerAccess
{
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

   unless ( $Input =~ /(\S+)@(\S+)\s+(\S+)/ )
   {
      WrLog("Error\tAddUser Value format error \"$Input\"",
      	    "     \t- The format should be \"user\@mail.domain password\"");
      return 1;
   }
   $User=$1;
   $Domain=$2;
   $Password=$3;
   
   return RunMgr("DOMAIN ADD \'$Domain\'","USER \'$Domain\' ADD $User CPASS=\'$Password\'");
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
   my $Backup=BackupFile($FileName);
   my $Single;
   
   unless ( $Backup )
   {
       	WrLog("Error\tFail to Backup $FileName .");
 	return 1;  	    
   }
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
   	if ( -e $Backup )
   	{
   	    WrLog("Info\tResotring the Original file $FileName");
   	    $Err += RunCmds("mv -f $Backup $FileName");
   	}
   } else
   {
   	WrLog("Note:\tTo restore the file use $Backup\n");
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
	   NetworkDomain	=> \&NotReadyYet ,
	   ExternalMTA		=> \&NotReadyYet ,
	   AllowDomains		=> \&AddAccessRule ,
	   AllowIPs		=> \&AddAccessRule ,
	   ManagerPassword	=> \&NotReadyYet ,
	   AllowManagerIPs	=> \&AddManagerAccess ,
	   AddUser		=> \&AddUser );
	   
my $Err=$G_ErrorCounter;
my %MTACustom=ReadConfig($G_CLIParams{Answer});
if ( $Err != $G_ErrorCounter )
{
   EndProg(1,"Fatal - Fail to read answer file \"$G_CLIParams{Answer}\". Skip MTA configuration.");
}

while ( my ($Param,$PValue) = each(%MTACustom) )
{
      unless ( defined $Func{$Param} )
      {
      	 WrLog("Error - Unknown parameter \"$Param\". This parameter will be ignored");
      	 next ;
      }
      my $FuncName=$Func{$Param} ;
      if ( $FuncName->($PValue) != 0 )
      {
      	## {$FuncName}($PValue)
      	 EndProg(1,"Fatal - Fail to configure $Param ($PValue)");
      }
}
EndProg(0,"-- ## Finish successfuly ## --");