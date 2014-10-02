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
use XML::LibXML;
#########################################################
#  Global variables
#########################################################

my $G_ErrorCounter=0;
my %G_CLIParams=(  LogFile  => "-" ,
				   Caf		=> "CreateSystem-CAF.xml" );
my @G_FileHandle=();
my %G_SWIMConf;

sub usage
{
    print "$0 [-LogFile FileName] [-SCDBPath Scdb full path] [-PVVM Debug] [-SwimSys Debug] [-Kits Kits folder] [-Caf CafFile name to edit]\n";
	print "\tSCDBPath: folder Path of scdb.xml file where all topolgy files should exists ....\n";
	print "\tKits:     Kits folder - if you want to overwrite the swim configuration KitsFolder ...\n";
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

sub SearchFiles #$Folder,$Pattern
{
	my $Folder=shift;
	my $Pattern= ( shift or ".*"); 
	my $DIR;
	## WrLog("Debug - Pattern is $Pattern");
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
			push(@Result,SearchFiles($FDir,$Pattern));
		}
		return @Result;
	} else
	{
		close $DIR;
		return ;
	}
}

sub GetSCDBPath
{
	exists $G_CLIParams{SCDBPath} and return $G_CLIParams{SCDBPath} ;
	my $ConfFile="/usr/cti/conf/scdb/parameters.xml";
	my $EnvName="SCDB_XML";
	my $Result;
	if ( -e $ConfFile )
	{
		##  I Think that the Value at SCDB configuration is more relaible than environment .... ###
		my $XmlObj=XML::LibXML->new()->parse_file($ConfFile);
		$Result=$XmlObj->findvalue(q(//Parameter[@Name="SCDBFileLocation"]/Value/Item/@Value));
		WrLog("Info - SCDB Path resolved from $ConfFile");
	} else
	{
		###  Implementation for DR-0-196-650  Update SCDB Population scripts to use SCDB path environment variable instead of full path ##
		$Result=$ENV{$EnvName};
		WrLog("Info - SCDB Path resolved from system environment \"$EnvName\"");
	}
	WrLog("Info - SCDB Path is $Result");
	return $Result;
}

sub GetSwimConf 
{
	my $ConfFile="/usr/cti/conf/swim/swim/parameters.xml";
	my $XmlObj= -e $ConfFile ? XML::LibXML->new()->parse_file($ConfFile) : XML::LibXML->new()->parse_string("<Empty/>");
	my %Result = ( RootFolder => $XmlObj->findvalue("//Parameter[\@Name=\"RootDataFolder\"]/Value/Item/\@Value") );
	$Result{Kits} = exists $G_CLIParams{Kits} ? $G_CLIParams{Kits} : $XmlObj->findvalue("//Parameter[\@Name=\"KitsFolderPath\"]/Value/Item/\@Value") ;
	$Result{SysDir} = exists $G_CLIParams{SwimSys} ? $G_CLIParams{SwimSys} : sprintf("%s/%s",$XmlObj->findvalue("//Parameter[\@Name=\"RootDataFolder\"]/Value/Item/\@Value") ,
									$XmlObj->findvalue("//Parameter[\@Name=\"SystemsFolderName\"]/Value/Item/\@Value") ) ;
	my $CafFileName=$G_CLIParams{Caf};
	unless ( -e $CafFileName )
	{
		$CafFileName =~ /-CAF/ or $CafFileName . "-CAF" ;
		$CafFileName =~ /.xml$/ or $CafFileName . ".xml";
		-e $CafFileName or $CafFileName= "$Result{Kits}/AddService/$CafFileName" ;
	}
	-e $CafFileName and $Result{Caf}=$CafFileName;
	foreach my $Chk ( ("Caf","Kits","SysDir") )
	{
		exists $Result{$Chk} or WrLog("Warning - Fail to read Swim Configuration File ($ConfFile)"), last;
		WrLog("Debug - Check existence of $Chk");
		-e $Result{$Chk} or WrLog("Warning - Fail to read Swim Configuration File ($ConfFile)"), last;
	}
	return $G_ErrorCounter ? undef : %Result ;
}

sub GetPVVMList
{
	exists $G_CLIParams{PVVM} and return split(/,/,$G_CLIParams{PVVM});
	my $ScdbPath=GetSCDBPath();
	my @Result;
	####   Search Systems at Mapping files or sub folders ...  ###
	if ( -e "$ScdbPath/SystemList.xml" )
	{
		my $XmlObj=XML::LibXML->new()->parse_file("$ScdbPath/SystemList.xml");
		my @SysList=$XmlObj->findnodes("//SystemRoot");
		foreach my $SysObj (@SysList)
		{
			my $SysName=$SysObj->getAttribute("SystemName");
			$SysName and push(@Result,$SysName);
		}
	} else
	{		###    File SystemList.xml not exists (maybe old scdb ... ) search for folders ... ##
			my @SysList=SearchFiles("$ScdbPath/UnitGroups","UnitGroup.xml\$");
			foreach my $SysObj (@SysList)
			{
				$SysObj =~ /\/([^\/]+?)\/UnitGroup.xml/ and push(@Result,$1);
			}
	}
	return @Result;
}

sub GetSwimSys
{
	exists $G_CLIParams{SwimSys} and return split(/,/,$G_CLIParams{SwimSys});
	## my %SwimConf=GetSwimConf();
	my @Result;
	foreach my $DirName ( SearchFiles($G_SWIMConf{SysDir},"UnitGroup.xml") )
	{
		$DirName =~ /\/([^\/]+?)\/UnitGroup.xml/ and push(@Result,$1);
	}
	## WrLog("Info - SwimSys Serach not Reday Yet ...");
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
%G_SWIMConf=GetSwimConf();
$G_ErrorCounter and EndProg(1,"Error - Fail to read Swim Configuration ...");
my @PVVMList=GetPVVMList();
my @SwimSysList=GetSwimSys();

my %ParamsMap= (  "SWIM SystemName"	=> \@SwimSysList ,
				  "PVVM System"		=> \@PVVMList );
				

my $MainXmlObj=XML::LibXML->new()->parse_file($G_SWIMConf{Caf});
my $CAFXmlObj=$MainXmlObj->documentElement();

while ( my ($Param,$ValList) =each(%ParamsMap) )
{
	my @ENumList=$CAFXmlObj->findnodes(sprintf("//Parameter\[\@Name=\"%s\"\]/Restrictions/Enum",$Param));
	@ENumList or EndProg(1,"Fail to find Enum Values for \"$Param\" at CAF $G_SWIMConf{Caf}");
	my $NewVals=XML::LibXML::Element->new("Enum");
	$CAFXmlObj->replaceChild($NewVals, $ENumList[0]);
	foreach my $Iter ( @$ValList ) 
	{
		my $ItemNode=$NewVals->appendChild(XML::LibXML::Element->new("Item"));
		$ItemNode->setAttribute("Value", $Iter);
	}
}
my $TmpStr=$MainXmlObj->toString();
$TmpStr=~ s/>\s+</></g ;
$CAFXmlObj=XML::LibXML->new()->parse_string($TmpStr);
$TmpStr=BackupFile($G_SWIMConf{Caf});
-e $TmpStr and $CAFXmlObj->toFile($G_SWIMConf{Caf},1);
$G_ErrorCounter += RunCmds("chown swim:swim $G_SWIMConf{Caf}");
my $ErrMessage= $G_ErrorCounter ? "Finish with ERRORS see Log File $G_CLIParams{LogFile}" :
		"Finish Successfully :-)";
EndProg($G_ErrorCounter,$ErrMessage);