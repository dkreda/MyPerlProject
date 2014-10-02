#!/usr/cti/apps/CSPbase/Perl/bin/perl

use strict;
use XML::LibXML;
#########################################################
#  Global variables
#########################################################

my $G_ErrorCounter=0;
my %G_CLIParams=(  LogFile  => "-" ,
				   TaskDef	=> "HostOrGroupName,LocalPath,RemotePath,Include");

sub usage
{
    print "This script adds Tasks to ftmTask file - if the task already exists it won't be added\n";
	print "Usage:\n";
	print "$0 -Dest FtmTask File Path -Merge TemplateFiles [-LogFile FileName]\n";
	print "$0 -help\n";
	print " -Dest\tFull Path of the Target file which the Task should be added to\n" ;
	print "      \tusually this file would be FtmTask.xml\n";
	print " -Merge\tList of Template file which contains Task to add to FtmTask\n"
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
     WrLog(@_);
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
# Description: Write the @Content Lines into $FileName (overite the file).
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

sub DualMerge
###############################################################################
#
# Input:	Template,Dest
#
# Return:
#
# Description:
#
###############################################################################
{
   my $Template=shift;
   my $Dest=shift;
   my $ElementName="Transfer";
   my ($Found,$TemplateStr,$DestStr);
   ## my @ElementChk=("HostOrGroupName","LocalPath","RemotePath","Include");
   my @ElementChk=split(/,/,$G_CLIParams{TaskDef});
   
   my $Counter=0;
   foreach my $TemplateTask (   $Template->findnodes("//$ElementName")  )
   {
		$Found=0;
		$Counter++;
		my %SearchTask=();
		### Map all Task Indexs
		my $TmpXPath=$TemplateTask->nodePath();
		
		## WrLog("Debug - Check Task $Counter at Template ($TmpXPath) ....");
		foreach my $Element (@ElementChk)
		{
			my @TemplateList=$TemplateTask->findnodes("$TmpXPath//$Element");
			unless ( @TemplateList )
			{
				WrLog("Warning - Task at template has missing tag \"$Element\"");
				next;
			}
			$SearchTask{$Element}=$TemplateList[0]->textContent;
			## WrLog("Debug - Templat Vlaue of $Element : $SearchTask{$Element} :",$TemplateList[0]->toString);
		}
		### Search the Task in Target
		foreach my $DestTask ($Dest->findnodes("//$ElementName") )
		{
			my $Flag=keys(%SearchTask);
			$TmpXPath=$DestTask->nodePath();
			## WrLog("Debug - Start check at Target :   $TmpXPath");
			while ( my ($TagName,$TagVal) = each (%SearchTask) )
			{
				$TmpXPath=$DestTask->nodePath();
				## WrLog("Debug Search at Target: $TmpXPath");
				my @TmpNode=$DestTask->findnodes("$TmpXPath//$TagName");
				@TmpNode or last ;
				## WrLog("Debug  Template -> $TagName = $TagVal",sprintf("Debug  Target $TmpXPath//$TagName = %s",$TmpNode[0]->nodeValue));
				my $MatchFlag= exists $G_CLIParams{i} ? $TmpNode[0]->textContent =~ /^$TagVal$/i : $TagVal eq $TmpNode[0]->textContent ;
				$MatchFlag or last;
				$Flag--;
			}
			### WrLog("Debug - Finish Search   $TmpXPath .....................................");
			$Flag and next;
			WrLog("Info - Task $Counter already exist at Target - This Task will be ignored");
			$Found=1;
			last;
		}
		
		unless ( $Found )
		{
			$Dest->documentElement()->appendChild($TemplateTask);
			WrLog("Info - Add New Task ($Counter) to Target");
		}
   	}
   return 0;
}

sub MultiMerge
###############################################################################
#
# Input:	$Dest,@ListofTemplates
#
# Return:
#
# Description:
#
###############################################################################
{
   my $DestFile=shift;
   my @RestTemplate=@_;
   #  my $Err-0;
   my $Desttree = XML::LibXML->new()->parse_file($DestFile);
   while ( @RestTemplate )
   {
   	my $TemplateFile=shift(@RestTemplate);
   	## my $TempParser=XML::LibXML->new();
   	my $TempTree=XML::LibXML->new()->parse_file($TemplateFile);
	## my $TempRoot=$TempTree->getDocumentElement;
   	DualMerge($TempTree,$Desttree) or next;
	WrLog("Error - an Error Ocured during Dual merge ...");
   	return 1;
   }
   my $TmpStr=$Desttree->toString();
   $TmpStr =~ s/>\s+</></g;
   my $TmpXml=XML::LibXML->new()->parse_string($TmpStr);
   BackupFile($DestFile) or return 1 ;
   return $TmpXml->toFile($DestFile,1) ? 0 : 1;
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
    	    defined  $G_CLIParams{$ParamName} and $G_CLIParams{$ParamName} .= ",";
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
    defined  $G_CLIParams{$ParamName} and $G_CLIParams{$ParamName} .= ",";
    $G_CLIParams{$ParamName} .= join(',',@ParamValue);

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
WrLog("Debug: Merge Files $G_CLIParams{Merge}");
WrLog("Debug: TaskDef -> $G_CLIParams{TaskDef}");
my @Templates=split(/,/,$G_CLIParams{Merge});
###my @Duplicates=grep(/^$G_CLIParams{Dest}$/,@Templates);
my %MergeFiles= map { $_ => 1 } @Templates ;

defined $MergeFiles{$G_CLIParams{Dest}} and delete $MergeFiles{$G_CLIParams{Dest}} ;
@Templates=keys(%MergeFiles);

$G_ErrorCounter += MultiMerge($G_CLIParams{Dest},@Templates);
my $ErrMessage= $G_ErrorCounter ? "Finish with ERRORS see Log File $G_CLIParams{LogFile}" :
		"Finish Succsefully :-)";
EndProg($G_ErrorCounter,$ErrMessage);