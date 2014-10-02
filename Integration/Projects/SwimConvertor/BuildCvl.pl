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
use XML::LibXML ;
#########################################################
#  Global variables
#########################################################

my $G_ErrorCounter=0;
my %G_CLIParams=(  LogFile  => "-" );
my @G_FileHandle=();

sub usage
{
    print "$0 -CVL List of cvl files -Target Target xml File -Map csv file -Kits kits folder [-Sys system folder] [-LogFile FileName]\n";
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

sub ReadUnitMap
{
	my $CsvFileName=shift;
	my @CsvUnitRec=ReadFile($CsvFileName);
	my %Result;
	foreach my $Line  (@CsvUnitRec) 
	{
			####  Ignore the Title
		$Line =~ /Octopus Unit Type/ and next ;
		my @Fields=split(/,/,$Line);
		$Result{$Fields[0]}= { GroupName => $Fields[1] ,
							   Platform  => $Fields[2] };
	}
	return %Result;
}

sub SetCVLName #File,Path
{
	my $FileName=shift;
	my $FilePath=shift;
	-e $FileName and return $FileName;
	my $Result = $FileName =~ /CVL.xml$/ ? $FileName : $FileName . "CVL.xml";
	unless ( -e $Result )
	{
		$FilePath =~ s/[\/\\]\s*$// ;
		length ($FilePath) > 1 and $FilePath =~ $FileName and undef $FilePath ;
		if ( $FilePath )
		{
			$Result = -e "$FilePath/$FileName" ? "$FilePath/$FileName" : "$FilePath/$Result" ;
		}
	}
	return $Result ;
}

sub SearchFiles #$Folder,$Pattern
{
	my $Folder=shift;
	my $Pattern= ( shift or ".*"); 
	my $DIR;
	my $Err = opendir( $DIR , $Folder) ;
	if ( $Err )
	{
		my @List=readdir($DIR);
		close($DIR);
		my @Folders;
		map { -d "$Folder/$_" and /(^[^\.])|([^\.]$)/ and push(@Folders,"$Folder/$_") } @List ;
		my @Result = map { $Folder . "/$_" } grep(/$Pattern/,@List);
		foreach my $FDir (@Folders)
		{
			push(@Result,SearchFiles($FDir));
		}
		return @Result;
	} else
	{
		close $DIR;
		return ;
	}
}

sub GetUAFs ## Folder
{
	my $UAFFolder=shift;
	my @FileList=SearchFiles($UAFFolder,"UAF.xml\$");
	my %Result;
	foreach my $File (@FileList) 
	{
		my $XmlObj=XML::LibXML->new()->parse_file($File);
		my $Unit=$XmlObj->findvalue("//UnitType/\@Name");
		$Result{$Unit}=$XmlObj;
	}
	return %Result;
}

sub InsertToCVL #$CVL,$Comp,$Unit,$Ver
{
	my $CVL=shift;
	my $Comp=shift;
	my $Unit=shift;
	my $Ver=shift;
	my @CompList=$CVL->findnodes("//Component[\@Name=\"$Comp\" and \@UnitType=\"$Unit\"]");
	if ( @CompList )
	{
		$CompList[0]->setAttribute("Version",$Ver);
		WrLog("Warning - component $Comp ($Unit) Already exists at CVL - Overwrite the version");
	} else
	{
		my $TmpObj=$CVL->appendChild(XML::LibXML::Element->new("Component"));
		$TmpObj->setAttribute("Name",$Comp);
		$TmpObj->setAttribute("UnitType",$Unit);
		$TmpObj->setAttribute("Version",$Ver);
		WrLog("Debug - Insert New Compnent:",$CVL->toString());
	}
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
####   Read SWIM - CVL xml File (Target)  ###
my ($TargetCVL,@CVLCompList);
my $CVLFileName=SetCVLName($G_CLIParams{Target},$G_CLIParams{Sys});
## EndProg(0,"Target File is $CVLFileName");
$TargetCVL= -e $CVLFileName ? XML::LibXML->new()->parse_file($CVLFileName) : XML::LibXML->new()->parse_string("<ComponentVersionList/>");
###   Read The Map File
my %Map=ReadUnitMap($G_CLIParams{Map});

### Read UAF Files
my %UAFObjs=GetUAFs($G_CLIParams{Sys});

###  Start Parse all Cvls ....
foreach my $CVLFile ( split(/,/,$G_CLIParams{CVL}) )
{
	my @CVLContent=ReadFile($CVLFile);
	@CVLContent < 2 and $G_ErrorCounter++ , WrLog("Error - Cvl File $CVLFile is empty or missing Skip this file.") , next;
	foreach my $Line ( @CVLContent )
	{
		my @Rec=split('\|',$Line);
		@Rec < 7 and WrLog("Warninig - The Line \"$Line\" contains less than 7 records - Ignore this line"), next;
		my @TmpArray=@Rec[0,1,2,6];
		push(@CVLCompList,\@TmpArray);
	}
}

$TargetCVL or $G_ErrorCounter++ , WrLog("Error - Fail to Read/Create Target CVL File \"$CVLFileName\"");
@CVLCompList > 1 or $G_ErrorCounter++ , WrLog("Error - No Components Found at CVL ...");
unless ( $G_ErrorCounter )
{
	WrLog("Debug - start Build CVL ....");
	## WrLog("CI\t\t\tVer\tBuild\tUnits");
	my $RootElement=$TargetCVL->findnodes("//ComponentVersionList")->[0];
	foreach my $CVLRec ( @CVLCompList )
	{
		my $VerStr=$CVLRec->[2] ? "$CVLRec->[1]-$CVLRec->[2]" : $CVLRec->[1] ;
		my @FolderList=SearchFiles($G_CLIParams{Kits},"$CVLRec->[0]\.*$CVLRec->[1]\.*$CVLRec->[2]");
		if ( @FolderList > 1 )
		{
			WrLog("Warning - There are more than one Matching Components Release of $CVLRec->[0] - $VerStr :",@FolderList);
		} elsif ( @FolderList < 1 )
		{
			WrLog("Warning - Component $CVLRec->[0] - $VerStr have not Found - This Component will be ignore !");
			### WrLog("Debug - Serach was $G_CLIParams{Kits}   and  => $CVLRec->[0]\.*$CVLRec->[1]\.*$CVLRec->[2] ...");
			next;
		}
		#### List CAF ! ####
		my %ComponetVer=();
		my @CafFileList=SearchFiles($FolderList[0],"CAF.xml\$");
		foreach my $File (@CafFileList)
		{
			my $XmlObj=XML::LibXML->new()->parse_file($File);
			my $CompName=$XmlObj->findvalue("//Component/\@Name");
			my $CompVer=$XmlObj->findvalue("//Component/\@Version");
			$ComponetVer{$CompName}=$CompVer;
		}
		foreach my $UnitType ( split(/,/,$CVLRec->[3] ) )
		{
			exists $Map{$UnitType} or WrLog("Warning - UnitType \"$UnitType\" not Exists at Map File - Component $CVLRec->[0] will be Ignore for this Unit") , next;
			## WrLog("Debug - Build Comp for $UnitType -> \"$Map{$UnitType}\"");
			while ( my ($CompName,$CompVer) = each ( %ComponetVer ) )
			{
				#exists $UAFObjs{$Map{$UnitType}->} or WrLog("Debug    ---  There is no UAF for 
				exists $UAFObjs{$Map{$UnitType}->{GroupName}} or next;
				$UAFObjs{$Map{$UnitType}->{GroupName}}->findnodes("//Component[\@Name=\"$CompName\"]") or next;
				InsertToCVL($RootElement,$CVLRec->[0],$Map{$UnitType}->{GroupName},$CompVer);
				### WrLog("","Debug - After InsertToCVL :",$RootElement->toString(),"");
			}
		}
	}
	my $TmpStr=$TargetCVL->toString();
	### WrLog("Debug - Saving (Target CVL:)",$TmpStr,"","","","Root Element:",$RootElement->toString());
	$TmpStr =~ s/>\s+</></g ;
	my $TmpXmlObj=XML::LibXML->new()->parse_string($TmpStr);
	$G_ErrorCounter  += $TmpXmlObj->toFile($CVLFileName,1) ? 0 : 1;
}
my $ErrMessage= $G_ErrorCounter ? "Finish with ERRORS see Log File $G_CLIParams{LogFile}" :
		"Finish Successfully :-)";
EndProg($G_ErrorCounter,$ErrMessage);