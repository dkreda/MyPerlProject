use strict;
#########################################################
#  Global variables
#########################################################

my $G_ErrorCounter=0;
my %G_CLIParams=(  LogFile  => "-" );
my @G_FileHandle=();

sub usage
{
    print "$0 [-LogFile FileName]\n";
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
    	PrnTitle("Start $0",
				 sprintf("at  %02d/%02d/%4d %02d:%02d:%02d",$DArr[3],$DArr[4]+1,$DArr[5]+1900,$DArr[2],$DArr[1],$DArr[0]));
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

my %BuildRec= ( el5	=> ["i386",
						{ ProfileDefinition_WHC 	=> "WHCProfileDefinition_Rel5.spec" ,
						 ProfileDefinition_VI	=> "VIProfileDefinition_Rel5.spec" ,
						 ProfileDefinition_MMG	=> "MMGProfileDefinition_Rel5.spec" } ],
						 
				el6	=> ["i686",
						{ ProfileDefinition_WHC 	=> "WHCProfileDefinition_Rel6.spec" ,
						 ProfileDefinition_VI	=> "VIProfileDefinition_Rel6.spec" ,
						 ProfileDefinition_MMG	=> "MMGProfileDefinition_Rel6.spec" } ]
				) ;
my $OS=`uname -a` || $G_CLIParams{OS};	
$OS =~ /\.(el\d+)/ and $OS=$1;
my $VIEWDIR=`pwd` || `echo %CD%`;
$VIEWDIR =~ s/\/[^\/]+?$// ;
exists $BuildRec{$OS} or EndProg(1,"Fatal - unsupported operation System $OS");

while ( my ($RpmName,$RpmSpec) = each (%{$BuildRec{$OS}->[1]}) )
{
	$G_ErrorCounter+=RunCmds( qq/rpmbuild -bb -v -D "ViewDir $VIEWDIR" 	\
							-D "_rpm_name $RpmName"						\
							-D "_rpm_version $G_CLIParams{Ver}" 		\
							-D "_rpm_stf $G_CLIParams{Build}" 			\
							-D "stf $G_CLIParams{Build}" 				\
							-D "product $RpmName"						\
							-D "version $G_CLIParams{Ver}"/ );
}

foreach my $CafFile ( SearchFiles("$VIEWDIR/..","CAF.xml\$") )
{
	 my @Content=ReadFile($CafFile);
	 for ( my $i=0; $i<=$#Content ; $i++ )
	 {
		$Content[$i] =~ s/\{RpmLocation\}/$BuildRec{$OS}->[0]/ ;
	 }
	 $G_ErrorCounter += WriteFile($CafFile,@Content);
}

my $ErrMessage= $G_ErrorCounter ? "Finish with ERRORS see Log File $G_CLIParams{LogFile}" :
		"Finish Successfully :-)";
EndProg($G_ErrorCounter,$ErrMessage);