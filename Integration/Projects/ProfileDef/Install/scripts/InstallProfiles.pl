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
my %G_CLIParams=(  LogFile  => "-" ,
					ProfLocatorDir	=> "/usr/cti/conf/profiledefinition" ,
					Oracle_GrpName	=> "Oracle" );
my @G_FileHandle=();

sub usage
{
    print "$0 -Services <Yes,No,....> -Conf <csv File configuration> [-LogFile FileName]\n";
    print "$0 -help\n";
    print "\n\twhere Services = list sperated by comma (,) of the requeired services.\n";
    print "\tand     Conf     = csv file name which contain the resource defnition table\n";
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

sub MaxLength
{
    my ($First,$Second)=(length($_[0]),length($_[1]));
    return $First > $Second ? $First : $Second;
}

sub CheckTitle #CsvTitle,$Services
{
    my ($CsvTitle,$Services)=@_;
    my $StartPostion=3;
    $CsvTitle =~ /ResourceName/i or return;
    my @Title=("  +","  +");
    my @ServiceName=split(/,/,$CsvTitle);
    my @InputServices=split(/,/,$Services);
    my @Result=@ServiceName[0..$StartPostion-1];
    @ServiceName=@ServiceName[$StartPostion..$#ServiceName];
    unless ( $#ServiceName == $#InputServices )
    {
    	WrLog(sprintf("Error - Number of Input services (%d) don't match the number of",$#InputServices+1),
    	      sprintf("        requiered services (%d) at csv file",$#ServiceName+1));
    	$G_ErrorCounter++; 
    	return ;
    }
    for ( my $Indx=0; $Indx <=$#ServiceName ; $Indx++ )
    {
    	$StartPostion=MaxLength($ServiceName[$Indx],$InputServices[$Indx]) + 1;
    	$Title[0] .= sprintf("%${StartPostion}s ",$ServiceName[$Indx]);
    	$Title[1] .= sprintf("%${StartPostion}s ",$InputServices[$Indx]);
    }
    WrLog("Info - Service Definition Input:",@Title);
    return @Result;
}

sub UpdateFiles #\%ResurceRec,\@ResList
{
    my $ResRec=shift;
    my $AppList=shift;
	my @Cmds;
    WrLog("Info - Start Enable/Disable Files");
	
	my $HostName=`hostname -s`;
	chomp $HostName;
	my $State=getVeritasStat($G_CLIParams{Oracle_GrpName},$HostName);
	unless ( $State =~ /onLine/i )
	{
		WrLog("Info - Oracle on this Machine is not Online ! - This machine wont run OracleAPI");
		$State="echo - Save :";
	} else 
	{
		$State="./bin/oracleApi.sh";
	}
    foreach my $Iter (@$AppList)
    {
    	my $Message=sprintf("Info - File %-20s %s",$Iter,$$ResRec{$Iter});
    	WrLog($Message); 
		push(@Cmds,$ResRec->{$Iter} =~ /Enable/i ? qq(su - ora_api -c "$State $G_CLIParams{ProfLocatorDir}/$Iter") 
								: "rm -f $G_CLIParams{ProfLocatorDir}/$Iter") ;
    }
    return RunCmds(@Cmds);;
}

sub SetResource # $FileName,$Services
{
    my $FileName=shift;
    my $ServiceStr=shift;
    my $Err=$G_ErrorCounter;
    my @TableContent=ReadFile($FileName);
    my (@FarmList,@AppList,@SessionNames,@SessionTypes,@ServiceName,@Field,%ResourceStatus,@FilesResource,@CheckList,@ParamsList);
    my %NotOp=( enable	=>	"disable" ,
				disable	=>	"enable" );
    my %Type=( "File"	   => [\@FilesResource,\&UpdateFiles] );
    unless ($Err == $G_ErrorCounter)
    {
    	WrLog("Error - Fail to read csv file \"$FileName\". skip Resource Configuration.");
    	return 1;
    }
    while ( @TableContent )
    {
    	@Field=CheckTitle(shift(@TableContent),$ServiceStr) and last;
    	$G_ErrorCounter > $Err and return 1;
    } 
	## WrLog("Debug - Title is:",@Field);
    foreach my $Line (@TableContent)
    {
    	####  Read Csv Record    #######
    	my %Record;
    	foreach my $Name (@Field) 
    	{
    	   $Name=lc($Name);
    	   $Line =~ s/^(.+?),// and $Record{$Name}=$1;
    	}
    	unless ( defined $Type{$Record{type}} )
    	{
    	     WrLog("Error - Unknowen Resource Type \"$Record{type}\" at Resource $Record{resourcename}");
    	     $G_ErrorCounter++;
    	     next;
    	}
    	unless ( exists $Record{operand} and exists $NotOp{lc($Record{operand})} )
    	{
    	    WrLog("Error - unknown Operand value \"$Record{operand}\" Skip calculation of $Record{ResourceName}");
    	    $G_ErrorCounter++;
    	    next;
    	}
    	$Line =~ s/(N\/A)|(Any)|\*/\[^,\]\+\?/ig ;
    	## WrLog("Debug - Analayze Resource $Record{ResourceName} - operand value = $Record{operand}");
    	## WrLog(sprintf("Debug -   Not of  $Record{ResourceName} - %s",$NotOp{lc($Record{operand})}) );
    	$ResourceStatus{$Record{resourcename}}= $ServiceStr =~ m/$Line/i ? 
    					$Record{operand} : $NotOp{lc($Record{operand})};
   	my $RecArrayP=$Type{$Record{type}};
   	push(@{$$RecArrayP[0]},$Record{resourcename});
    }
    
    while ( my ($ResType,$ResRec) = each(%Type) )
    {
    	WrLog("Info - update Resources $ResType");
    	my ($ArryPointer,$Func)=@$ResRec;
    	$#{$ArryPointer} < 0 and next;
    	if ( $Func->(\%ResourceStatus,$ArryPointer) )
    	{
    	   my @Messages=("Error - Fail to update some of the Resources \"$ResType\"",
    	            "        Going to update next resource - but check the log for errors");
    	   PrnTitle(@Messages);
    	   WrLog("","");
    	   $G_ErrorCounter++;
    	   #####   Just Clear Erros   ####
    	   while ( $? ) { my $Tmp=`echo`; }
    	}
    }
    
    return $G_ErrorCounter - $Err;
    
}

sub getVeritasStat #ResGroup
{
	my $ResGroup=shift;
	my $HostName=shift;
	my $RegExpStr= $HostName ? "$ResGroup -sys $HostName" : $ResGroup ;
	my @Lines=`hagrp -state $RegExpStr`;
	chomp(@Lines);
	@Lines > 1 or return $Lines[0];
	shift @Lines;
	my $Result;
	foreach my $Line ( @Lines )
	{
		$Line =~ /((\S+)(\s+|$)){4}/ and $RegExpStr=$2 and $RegExpStr=~ /OnLine/i and $Result=$RegExpStr;
	}
	$Result or $Result= $Lines[0] =~ /(\S+)\s*$/ ? $1 : "Error";
	$Result =~ s/[\|]//g;
	return $Result ;
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
my $OracleState=getVeritasStat($G_CLIParams{Oracle_GrpName});
$OracleState =~ /OnLine/i or EndProg(1,"Error - Oracle is down at Cluster ($G_CLIParams{Oracle_GrpName}). Fix the problem and run again");
$G_ErrorCounter += SetResource($G_CLIParams{Conf},$G_CLIParams{Services});
unless ( $G_ErrorCounter )
{
	my $HostName=`hostname -s`;
	chomp $HostName;
	my $State=getVeritasStat("ProfileLocator",$HostName);
	if ( $State =~ /onLine/i )
	{
		my $Counter;
		WrLog("Debug - Shutdown ProfileLocatore ...");
		$G_ErrorCounter += RunCmds("hagrp -offline ProfileLocator -sys $HostName");
		do { sleep(3); $State=getVeritasStat("ProfileLocator",$HostName); } until ( $State !~ /OnLine/i );
		$State=getVeritasStat("ProfileLocator");
		$State !~ /OnLine/i and RunCmds("hagrp -online ProfileLocator -sys $HostName");
		for ( $Counter=15 ; $State !~ /OnLine/i and $Counter > 0 ; $Counter-- )
		{
			sleep(10);
			$State=getVeritasStat("ProfileLocator");
		}
		WrLog("Debug - Last State is $State ....");
		$Counter or WrLog("Error - TimeOut, Resource Group ProfileLocator fail to start during Timeout perioud"),$G_ErrorCounter++;
	}
}
my $ErrMessage= $G_ErrorCounter ? "Finish with ERRORS see Log File $G_CLIParams{LogFile}" :
		"Finish Successfully :-)";
EndProg($G_ErrorCounter,$ErrMessage);