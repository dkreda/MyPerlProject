#!/usr/cti/apps/CSPbase/Perl/bin/perl

##################################################################
#  18/9/2011 
#	This scriptPick up environment parameters such as
#	Hardware Type , Unit Type , Balancer etc ...
#	it is used to merge MMSGW and Vi Service kit ...
#
#   Todo:
#

use strict;
use XML::LibXML ;

#########################################################
#  Global variables
#########################################################

my $G_ErrorCounter=0;
my %G_CLIParams=(  LogFile  => "-" ,
		   HW	    => "Auto" );
my @G_FileHandle=();
### my $G_RecSep="%%%";
##my $G_Null="\$NULL";
my %G_OSCmds;
my $G_CspPath="/usr/cti/apps/CSPbase";

sub usage
{
    print "$0 -Conf Filename -Dest ResultFileName [-LogFile FileName]\n";
    print "$0 -help\n";
    print "* Conf    - configuration file. which contains all parameters mapping.\n";
    print "* LogFile - logger file name.\n";
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
    	my @DArr=localtime();
    	my @WeekDays=("Sunday","Monday","Tuesday","Wednesday","Thurthday","Friday","Saturday");
    	PrnTitle("Start $0",sprintf("at %-14s %02d/%02d/%4d $DArr[2]:%02d",$WeekDays[$DArr[6]],$DArr[3],
    			$DArr[4]+1,$DArr[5]+1900,$DArr[1]));
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
   my @DArr=localtime();
   my $BackFile=sprintf("%4d_%02d_%02d_%02d%02d%02d",$DArr[5]+1900,$DArr[4]+1,$DArr[3],$DArr[2],$DArr[1],$DArr[0]);
   my $Suffix="Backup_";
   my $JustFile ;
   
   unless ( -e $OrigFile )
   {
   	WrLog("Error\tFail to backup file $OrigFile. file Not exists.");
   	$G_ErrorCounter++;
   	return "";
   }
   $BackFile = "$OrigFile.$Suffix$BackFile";
   $OrigFile =~ m/(^|\/)([^\/]+)$/ ;
   $JustFile = $2;
   WrLog ("Info\tBackup File $JustFile ...");
   if ( RunCmds("$G_OSCmds{Copy} $OrigFile $BackFile") )
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

sub ParseSections 
###############################################################################
#
# Input:	\%IniRec
#
# Return:	0 - O.K 1 Error
#
# Description:  Parse the content and retun Update IniRec
#		IniRec = {SecTion Name} [startLine,EndLine]
#		Resrved names (FileName,Content)
#
###############################################################################
{
    my $Pointer=shift;
    ### WrLog("--- Debug in ParseSections ....","","");
    unless ( defined $$Pointer{Content} )
    {
    	WrLog("Error - IniRec is missing. ParseSections get empty content. file name \"$$Pointer{FileName}\"");
    	return 1;
    }
    ## WrLog("Debug:\tParsing ini file \"$$Pointer{FileName}\"");
    my $Content=$$Pointer{Content};
    my ($SecName,$LastName);
    my $Start=0;
    my $Tmp = $#$Content ;
    ## WrLog("Debug - Number of Lines: $Tmp");
    for ( my $Indx=0 ; $Indx <= $#$Content ; $Indx++ )
    {
    	$$Content[$Indx] =~ /^\s*\[(.+)\]/ or next ;
    	$SecName=$1;
    	###defined $LastName or next ;
    	$$Pointer{$LastName}=[$Start,$Indx-1];
    	$Start=$Indx+1;
    	$LastName=$SecName;
    	## WrLog("Debug: Add Section $SecName ...");
    }
    defined $LastName and $$Pointer{$LastName}=[$Start,$#$Content];
    return 0;
}

sub ReadSections 
###############################################################################
#
# Input:	\%IniRec,@SectionName
# Return:  %Hash - contain all the key->val
#
# Description: transform from "param=val" to hash.
#
###############################################################################
{
    my $Pointer=shift;
    my @Sections=@_;
    ### WrLog("Debug:\tIni File $$Pointer{FileName}:",@Sections);
    my %Result;
    foreach my $Sec (@Sections)
    {
    	## WrLog("Debug:\tParsing Section $Sec");
    	unless ( defined $$Pointer{$Sec} )
    	{
    	    WrLog("Error: Fail to find sector \"$Sec\" at file $$Pointer{FileName}");
    	    $G_ErrorCounter++;
    	    next;
    	}
    	my $TmpPoint=$$Pointer{$Sec};
    	## WrLog("Debug - Section $Sec Range is :",@$TmpPoint);
    	my $ContPoint=$$Pointer{Content};
    	my @Lines=@$ContPoint[$$TmpPoint[0]..$$TmpPoint[1]];
    	## WrLog("Debug: Section $Sec Content:",@Lines);
    	foreach my $Line ( grep (/^\s*[^#]/,@Lines) )
    	{
    	    $Line =~ /(.+?)=(.+)/ or next ;
    	    ### This is Relevant if there is Multi values at Section ....
    	    my $Base=$1;
    	    my $KeyName=$Base;
    	    my $Count=0;
    	    while ( defined $Result{$KeyName} )
    	    {
    	    	$Count++;
    	    	$KeyName="$Base#$Count";
    	    }
    	    $Result{$KeyName}=$2;
    	}
    }
    return %Result;
}

sub SetSection
###############################################################################
#
# Input:	\%IniRec,$SectionName,%HashParam
#
# Return:	0 - O.K, 1 - Error
#
# Description:  Update parameters in section. if the parameter no exists add it.
#		if the section not exist add new section
#
###############################################################################
{
    my $IniRec=shift;
    my $SecName=shift;
    my %HashParams=@_;
    my @NewContent;
    my $Point=$$IniRec{Content};
    my ($StartIndx,$EndIndx);
    ### Check if the section already exists
    unless ( defined $$IniRec{$SecName} )
    {
    	WrLog("Info:\tNew section \"$SecName\" add to Ini file $$IniRec{FileName}");
    	push(@$Point,"[$SecName]");
    	$EndIndx=$#$Point;
    	$StartIndx=$EndIndx + 1;
    } else
    {
    	($StartIndx,$EndIndx)=@{$$IniRec{$SecName}};
    }
    @NewContent=@$Point[0..$EndIndx];
    ### update exist parameters at the section
    for ( my $LineNo=$StartIndx;  $LineNo <= $EndIndx ; $LineNo++ )
    {
    	$NewContent[$LineNo] =~ /^\s*([^#].*)=/ or next;
    	my $ParaName=$1;
    	exists $HashParams{$ParaName} or next ;
    	$NewContent[$LineNo]="$ParaName=$HashParams{$ParaName}";
    	delete $HashParams{$ParaName};
    }
    while ( my ($ParaName,$ParamVal) = each(%HashParams) )
    {
    	push (@NewContent,"$ParaName=$ParamVal");
    }
    my ($Indx1,$Indx2)=($EndIndx + 1, $#$Point);
    push(@NewContent,@$Point[$Indx1..$Indx2]);
    $$IniRec{Content}=\@NewContent;
    return ParseSections($IniRec);
}

sub LoadIniFile
###############################################################################
#
# Input:     $Filename
#
# Return:    %IniRec
#
# Description:  ReadInifile and return iniRec:
#               IniRec = {FileName} => The Ini File Name
#			 {Content}  => \@Ini FileContent Lines
#			 {<SecName>}=> (Start,End)
#
###############################################################################
{
    my $FileName=shift;
    my @Content=ReadFile($FileName);
    $#Content < 0 and WrLog("Error - Fail to read ini File."),return;
    my %Result = ( FileName	=> $FileName ,
    		   Content	=> \@Content );
    my $Err=ParseSections(\%Result);
    $Err and WrLog("Error: Parsing $FileName");
    return  $Err ? 0 : %Result ;
}

sub UpDateIniFile
###############################################################################
#
# Input:	\%IniRec
#
# Return:	0 - O.K , 1 Error
#
# Description: write ini File acording to content.
#
###############################################################################
{
    my $Rec=shift;
    my $Content=$$Rec{Content};
    my $Err = -e $$Rec{FileName} ? UpdateFile($$Rec{FileName},@$Content) : WriteFile($$Rec{FileName},@$Content);
    return $Err;
}

sub CreateIniFile
###############################################################################
#
# Input:	$FileName
#
# Return:	%IniRec
#
# Description:
#
###############################################################################
{
    my $FileName=shift;
    my @Content=();
    my %Result = ( FileName	=> $FileName ,
    		   Content	=> \@Content );
    return -e $FileName ? LoadIniFile($FileName) : %Result ;
}

sub FactoryOS
###############################################################################
#
# Input:       nothing
#
# Return:      0 -O.K 1 -Error
#
# Description:  Update Standard system commands depend on OS
#
###############################################################################
{
    my %OSCmds = ( linux    => ["cp -p","mv -f"] ,
    		   MSWin32  => ["copy","rename"] );
    unless ( defined $OSCmds{$^O} )
    {
    	WrLog("Error - Unknown operation system $^O");
    	return 1;
    }
    $G_OSCmds{Copy}=$OSCmds{$^O}->[0];
    $G_OSCmds{"Rename"}=$OSCmds{$^O}->[1];
    return 0;
}

sub getHardware
{
    WrLog("Info - Resolving Hardware Type ...");
    defined $G_CLIParams{HW} and return $G_CLIParams{HW};
    my $Err=0;
    my $Result=`cat /etc/.machine`;
    my $Err=$?;
    $Err and $Result="";
    $Result = length($Result) < 2 ? `$G_CspPath/csp_scanner.pl --machine_type` : $Result ; 
    $Err=$?;
    if ( $Err )
    {
    	WrLog("Warning\tFail to retreive Hardware Type.",
    	      "       \tThis may cause if CSP BASE is not install on this machine." );
    	$Result="Fail to Retreive Hardware";
    }
    chomp $Result;
    $G_ErrorCounter += $Err;
    ### Just Clear the System Error Param ##
    while ( $? ) { $Err=`` }
    WrLog("Info - find Out Haedware \"$Result\"");
    return $Result;
}

sub getUnit
{
    WrLog("Info - Resolving Unit Type ...");
    defined $G_CLIParams{Unit} and return $G_CLIParams{Unit};
    my %Conf=LoadIniFile("/usr/cti/conf/babysitter/Babysitter.ini");
    unless ( defined $Conf{FileName} )
    {
    	WrLog("Error - Fail to Retreive Unit Type");
    	$G_ErrorCounter++;
    	return ;
    }
    my %Params=ReadSections(\%Conf,"General");
    unless ( defined $Params{UnitType} )
    {
    	WrLog("Error - file $Conf{FileName} corapted fail to resolve UnitType parameter");
    	$G_ErrorCounter++;
    	return ;
    }
    WrLog("Info\tFind out Unit \"$Params{UnitType}\"");
    return $Params{UnitType};
}

sub getDNSIPs
{
    my %CheckFile = ( forwarders	=> "/etc/named.conf" ,
    		      nameserver	=> "/etc/resolv.conf" );
    WrLog("Info - Check for DNS Servers ...");
    my @Result=("127.0.0.1");
    my %IpKeys;
    while ( my ($Param,$File) = each(%CheckFile) )
    {
    	my @Content=grep(/$Param/,ReadFile($File));
    	WrLog("Debug - Check $Param at file $File");
    	foreach my $Line ( @Content )
    	{
    	     $Line =~ /^\s*#/ and next;
    	     while ( $Line =~ s/([\d\.]+)// )
    	     {
    	        $IpKeys{$1}=1 ;
    	     }
    	}
    }
    foreach (@Result)
    {
    	exists $IpKeys{$_} and delete $IpKeys{$_} ;
    }
    @Result=keys(%IpKeys);
    return @Result;
}

sub IsBalancer
{
    WrLog("Info - Check if This Machine is Balancer ...");
    my @DNSIps=@_;
    defined $G_CLIParams{Balancer} and return $G_CLIParams{Balancer};
    my $LocalIP=`hostname -i`;
    if ( $? )
    {
    	$G_ErrorCounter++;
    	WrLog("Error - Fail to Retreive Local IP");
    	### Just Clear the System Error Param ##
    	while ( $? ) { $LocalIP=`` }
    	return;
    }
    chomp($LocalIP);
    WrLog("Debug - Local IP is \"$LocalIP\"");
    
    return grep(/^$LocalIP$/,@DNSIps) ? "Yes" : "No";
}

sub getMips
{
    WrLog("Info - Mips Server Name and Ips ..."); 
    defined $G_CLIParams{Mips} and return $G_CLIParams{Mips};
    return "Not Ready Yet ...";
}

sub getOracles
{
    WrLog("Info - retreive Oracles Server Ips ..."); 
    defined $G_CLIParams{Oracle} and return $G_CLIParams{Oracle};
    return "Not Ready Yet ...";
}

sub getPVVM ### $IpList
{
    my @IpList=split(/,/,shift);
    my %Oracls=();
    
    foreach my $IpMach ( @IpList )
    {
    	my @Quary=`nslookup ODS $IpMach`;
    	chomp @Quary;
    	WrLog("Debug: ",@Quary,"------------","");
    	my $Flag=0;
    	foreach (@Quary )
    	{
    	   $_ =~ /Name:/ and $Flag=1;
    	   $Flag or next ;
    	   WrLog("Debug - Parssinf Line $_");
    	   $_ =~ /Address/ and /((\d+\.){3}\d+)/ and $Oracls{$1}=1;
    	}
    }
    my @Result=keys(%Oracls);
    WrLog("Debug - Found out the following Oracle IPs:",@Result);
    return @Result;
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
my %EnvParams;
while ( my ($PName,$PVal ) = each(%G_CLIParams) )
{
     push(@DebugMessages,sprintf("\t-%-20s = $PVal",$PName));
}
WrLog(@DebugMessages);

FactoryOS() and EndProg(1,"Fatal - unsupported operation system ...");

defined $G_CLIParams{Dest} or $G_CLIParams{Dest}="-";


my %Configuration=CreateIniFile($G_CLIParams{Dest});
defined $G_CLIParams{PVVM} and getPVVM($G_CLIParams{PVVM});
$EnvParams{Hardware}=$G_CLIParams{HW} =~ /Auto/ ? getHardware() : $G_CLIParams{HW};
$EnvParams{Unit}=getUnit();
my @IpList=getDNSIPs();
if ( $#IpList < 0 )
{
    WrLog("Error - Fail to retreive DNS Ip List");
    $G_ErrorCounter++ ;
}
$EnvParams{IsBalancer}=IsBalancer(@IpList);
$EnvParams{DNSIpList}=join(',',@IpList);
$EnvParams{MailServer}=getMips();
$EnvParams{Oracles}=getOracles();
$G_ErrorCounter += SetSection(\%Configuration,"Octopus.Parameters.Values",%EnvParams);

$G_ErrorCounter += UpDateIniFile(\%Configuration);

my $ErrMessage= $G_ErrorCounter ? "Finish with ERRORS see Log File $G_CLIParams{LogFile}"
		: "F I N I S H - S U C C E S S F U L L Y  :-)";
EndProg($G_ErrorCounter,$ErrMessage);