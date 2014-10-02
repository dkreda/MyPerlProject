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
my %G_CLIParams=(	Conf		=> "/usr/cti/conf/ServiceKit/HardwareConfig.ini",
					NextExec	=> "./OctParamsManipulation.pl" ,
					LogFile 	=> "-" );
my $G_CspPath="/usr/cti/apps/CSPbase";
my %G_HWList=();
my @G_FileHandle=();

sub usage
{
    print "$0 -Conf configFile [-Unit UnitType] [-HW HardwareType] [-LogFile FileName] [... -AnyinputParam Value]\n";
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
		my @DArr=localtime();
		PrnTitle(sprintf("Start $0 at %02d/%02d/%4d",$DArr[3],$DArr[4]+1,$DArr[5]+1900));
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

sub ReadConfig 
###############################################################################
#
# Input:	\@Input
#
# Return:  %Hash - SectionName ->[StartLine,EndLine]contain all the key->val
#
# Description: transform from Line "param=val" to hash.
#
###############################################################################
{
	my $Input=shift;
    my %Result=();
	#my %OSMap = ( "x86_64"	=> "64Bit" ,
	#			  "i686"	=> "32Bit" ,
	#			  "i386"	=> "16Bit" );
	my $SecName;
    for ( my $Counter=0 ; $Counter< @$Input ; $Counter++)
    {
    	$Input->[$Counter] =~ /^\s*\[(.+)\]/ or next ;
		defined $SecName and $Result{$SecName}->[1]=$Counter-1;
		$SecName=$1;
		$Result{$SecName}=[ $Counter+1,$Counter+1] ;
    }
	exists $Result{$SecName} and $Result{$SecName}->[1]=$#$Input;
	#my @List=`mpstat -P ALL`;
	#$List[-1] =~ /((\S+)\s*){3}/ and $Result{Cores}= $2 + 1 ;
	#@List=`uname -m`;
	#chomp @List;
	#exists $OSMap{$List[-1]} and $Result{OSType}=$OSMap{$List[-1]};
	$SecName=`` while ( $? ) ;
    return %Result;
}

sub getMachineConf # ConfFile,HWMachine , Unit
{
   my $File=shift;
   my $HWType=shift;
   my $Unit=shift;
   my $ErrFlag=0;
   my (@Params,@Vals,$Iter);
   my @Content=ReadFile($File);
   @Content or WrLog("Error - $File empty or not exists skip Haedware config"),$G_ErrorCounter++,return ;
   my %HWList=ReadConfig(\@Content);
   my %Result=();
   foreach $Iter ( split(/:/,$HWType) )
   {
		$Iter =~ /\d+Bit/i and $HWList{OSType}= exists $HWList{OSType} ? $HWList{OSType} : $Iter and next;
		$Iter =~ /(\d+)Core/i and $HWList{Cores}= exists $HWList{Cores} ? $HWList{Cores} : $1 and next;
		$Iter =~ /(\d+)Mem/i and $HWList{MachineMem} = $1 and next;
		$HWType=$Iter;
   }
   WrLog("Info - Check configuration for hardware \"$HWType\"");
   foreach $Iter ($HWType,"$HWType/$Unit")
   {
		exists $HWList{$Iter} or next;
		my @TmpLines=@Content[$HWList{$Iter}->[0]..$HWList{$Iter}->[1]];
		$ErrFlag++;
		foreach my $Line ( @TmpLines )
		{
			$Line =~ /^\s*#/ and next;
			$Line =~ /(.+?)=(.+)/ or next;
			my $ParamName=$1;
			my $ParamVal=$2;
			if ( $ParamVal =~ s/\s*For\s+(\d+Bit)\s*//i ) 
			{
				if ( exists $HWList{OSType} )
				{ 
					my $Tmp=$1;
					uc($HWList{OSType}) eq uc($Tmp) or next;
					WrLog("Info - Parameter \"$ParamName\" Match Operation System Type $HWList{OSType}");
				} else
				{
					WrLog("Error - fail to determine which operation system Type is running. Skip configuration of $ParamName") ;
					$G_ErrorCounter++;
					return ;
				}
			}
			if ( $ParamVal =~ /(\d+)\s*Per\s+Core/i )
			{
				unless ( exists $HWList{Cores} )
				{
					WrLog("Error - Can Not Determine The Value of \"$ParamName\" The system failed to find out how many cores in this Machines") ;
					$G_ErrorCounter++;
					return ;
				}
				$ParamVal=$1 * $HWList{Cores} ;
			}
			$Result{$ParamName}=$ParamVal;
		}
	}
	$ErrFlag or $G_ErrorCounter++,WrLog("Error - Fail to Find Hardware \"$HWType\" at configuration File \"$File\""),return;
	while ( my ($HwConf,$HwVal) = each(%HWList) )
	{
		ref $HwVal or $Result{"HW_$HwConf"}=$HwVal;
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
   if ( RunCmds("perl -MExtUtils::Command -e mv $OrigFile $BackFile") )
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

sub getHardware
{
	my %OSMap = ( "x86_64"	=> "64Bit" ,
				  "i686"	=> "32Bit" ,
				  "i386"	=> "16Bit" );
    WrLog("Info - Resolving Hardware Type ...");
    ## defined $G_CLIParams{HW} and return $G_CLIParams{HW};
	my $Err=0;
	my $Result= ( exists $G_CLIParams{HW} and $G_CLIParams{HW} =~ /^(\D.+?)(\:|$)/ ) ?  $1 : `cat /etc/.machine`;
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
	
	my @List=`mpstat -P ALL`;
	exists $G_CLIParams{HW} and $G_CLIParams{HW} =~ /(\d+)Core/i and push(@List,sprintf("0 0 %d",$1 -1 ));
	$List[-1] =~ /((\S+)\s*){3}/ and $Result .= sprintf(":%dCore",$2 + 1) ;

	@List= `uname -m`;
	chomp @List;
	my $OsBit= ( exists $G_CLIParams{HW} and $G_CLIParams{HW} =~ /(\d+)Bit/i ) ? "$1Bit" : $OSMap{$List[-1]} ; 
	if ( $OsBit )
	{
		$Result .=  ":$OsBit" ;
	} else
	{
		WrLog("Warning - Fail to determine which OS is runing (16Bit/32Bit or 64 bit)");
	}
	unless ( exists $G_CLIParams{HW} and $G_CLIParams{HW} =~ /(\d+)Mem/i )
	{
		@List=ReadFile("/proc/meminfo");
		my @TmpList = grep(/MemTotal/,@List);
		$TmpList[0] =~ /(\d+)/ and $Result .= ":$1Mem" ;
	} else
	{
		$Result .= ":$1Mem" ;
	}
    ### Just Clear the System Error Param ##
    while ( $? ) { $Err=`` }
    WrLog("Info - find Out Haedware \"$Result\"");
    return $Result;
}

sub getUnit
{
    WrLog("Info - Resolving Unit Type ...");
    exists $G_CLIParams{Unit} and return $G_CLIParams{Unit};
	my @Content=ReadFile("/usr/cti/conf/babysitter/Babysitter.ini");
	my %Conf=ReadConfig(\@Content);
	my @SecPart=@Content[$Conf{General}->[0]..$Conf{General}->[1]];
	my @Lines=grep(/\s*UnitType=/,@SecPart);
	unless ( $Lines[0] =~ /=\s*(\S+)/ )
	{
		EndProg(1,"Error - Fail to Determine which UnitType this Machine");
	}
	return $1;
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
    @ParamValue=();
    while ( $#ARGV >= 0 )
    {
    	$Iter = shift(@ARGV);
    	if ( $Iter =~ m/^-(.+)$/ )
    	{
    	    defined $ParamName and $G_CLIParams{$ParamName}=join(',',@ParamValue);
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
    defined $ParamName and $G_CLIParams{$ParamName}=join(',',@ParamValue);

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
my $HWType=getHardware();
my $UnitType=getUnit();
my %HWConf=getMachineConf($G_CLIParams{Conf},$HWType,$UnitType);
### ToDO Add Balancer check ....

### Start Update Value Section :
my @OldCont=ReadFile($G_CLIParams{Conf});
my %ConfSec=ReadConfig(\@OldCont);
unless ( exists $ConfSec{Values} )
{
	push(@OldCont,"[Values]");
	$ConfSec{Values}=[$#OldCont,$#OldCont];
}
my @ValueSec=@OldCont[$ConfSec{Values}->[0]..$ConfSec{Values}->[1]];
for ( my $Indx=0 ; $Indx < @ValueSec ; $Indx++ )
{
	$ValueSec[$Indx] =~ /^\s*([^#].+?)=/ or next;
	my $Tmp=$1;
	exists $HWConf{$Tmp} or next ;
	$ValueSec[$Indx] =~ s/=.+/=$HWConf{$Tmp}/ ;
	delete $HWConf{$Tmp};
}
while ( my ($ParamName,$ParamVal) = each(%HWConf) )
{
	push (@ValueSec,"$ParamName=$ParamVal");
}
my ($StartLine,$EndLine)=($ConfSec{Values}->[0]-1,$ConfSec{Values}->[1]+1);
$G_ErrorCounter += WriteFile($G_CLIParams{Conf},@OldCont[0..$StartLine],@ValueSec,@OldCont[$EndLine..$#OldCont]);
### Find the Location of OctParamManipulation"
unless ( $G_ErrorCounter )
{
	-x $G_CLIParams{NextExec} or EndProg(1,"Fatal - Can not  find file $G_CLIParams{NextExec} !");
	WrLog("Info - Start Run $G_CLIParams{NextExec} ...");
	exec("$G_CLIParams{NextExec} -Conf $G_CLIParams{Conf} -Unit $UnitType -LogFile $G_CLIParams{LogFile}");
}
my $ErrMessage= $G_ErrorCounter ? "Finish with ERRORS see Log File $G_CLIParams{LogFile}" :
		"Finish Successfully :-)";
EndProg($G_ErrorCounter,$ErrMessage);