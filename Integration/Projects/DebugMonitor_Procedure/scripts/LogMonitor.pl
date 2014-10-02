#!/usr/cti/apps/CSPbase/Perl/bin/perl

##############################################################################
# Log Monitor Script
# for use at solaris replace the first line with:
# #!/usr/local/bin/perl
#
# This scripts set debug ( or other level ) to components and restrt them
# when it requiars it archives all alog files in single zip file
##############################################################################

use strict;
use XML::LibXML;
use sigtrap 'handler', \&KillMySelf, 'any';


#########################################################
#  Global variables
#########################################################

my $G_ErrorCounter=0;
my %G_CLIParams=(  LogFile  => "-,/tmp/LogMonitor.log" );
my @G_FileHandle=();
my @G_Log;
my $G_Flag;
my $G_OutErr;

sub KillMySelf
{
	push(@G_Log,"Info  - Terminate Siganle resived - maybe Timeout ....");
	$G_OutErr and WriteFile($G_OutErr,@G_Log,$G_Flag);
	EndProg(1,"Warnning - UnNormal Termination (Exit due Signal Interupt)");
}

sub usage
{
	print "$0 -help\n";
    printf ("$0 -Conf Configfile -(%s) [-Remote [IpList]] [-LogFile FileName]\n",join('|',getOperation("all")));
    print "T.B.D\n";
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
    ### WrLog("Debug:\tParsing ini file \"$$Pointer{FileName}\"");
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
    	$LastName and $$Pointer{$LastName}=[$Start,$Indx-1];
    	$Start=$Indx+1;
    	$LastName=$SecName;
    	## WrLog("Debug: Add Section $SecName ...");
    }
    defined $LastName and $$Pointer{$LastName}=[$Start,$#$Content];
    return 0;
}

sub getSecContent #\%IniRec , SecName
{
    my $IniRec=shift;
    my $SecName=shift;
    unless ( exists $$IniRec{$SecName} )
    {
    	WrLog("Error - Section \"$SecName\" not exists at Ini File $$IniRec{FileName}");
    	$G_ErrorCounter++;
    	return undef;
    }
    my @TmpArray=@{$$IniRec{$SecName}};
    return @{$$IniRec{Content}}[$TmpArray[0]..$TmpArray[1]];
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
        my @Lines=getSecContent($Pointer,$Sec);
        @Lines or next;
    	## WrLog("Debug: Section $Sec Content:",@Lines);
    	foreach my $Line ( grep (/^\s*[^#]/,@Lines) )
    	{
    	    $Line =~ /(.+?[^\\])=(.+)/ or next ;
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
    	defined $HashParams{$ParaName} or next ;
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
    my $Err=$G_ErrorCounter;
    my @Content=ReadFile($FileName);
    $G_ErrorCounter > $Err and WrLog("Error - Fail to read ini File."),return;
    $#Content < 0 and WrLog("Warning - Content of $FileName is Empty !");
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

sub getSections  # \%IninRec
{
    my $IniRec=shift;
    my @ExludeList=("FileName","Content");
    my @Result=();
    ## WrLog("debug - getSections:");
    while ( my ($SecName,$RefArray) = each(%$IniRec) )
    {
        grep(/^$SecName$/,@ExludeList) and next;
        ## WrLog("Debug - $SecName  -> $RefArray ...$$RefArray[0]");
        ref($RefArray) eq "ARRAY" or next ;
        push(@Result,$SecName);
    }
    return wantarray ? @Result : $#Result ;
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
   while( $? ) { system("echo"); }
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

sub ExtractUnit # $Str,$Unit
{
    my $Str=shift;
    my $unit=shift;
    
    $Str =~ /^\s*#/ and return undef ;
    $Str =~ s/((.*),)?([^,]+)$/$3/ or return undef ;
    my $UnitStr = $2 ? $2 : $unit;
    my @Units=split(/,+/,$UnitStr);
    ## WrLog("Debug - ExtractUnit Check if $unit exists at ($UnitStr):",@Units,"","");
    return grep(/^$unit$/,@Units) ? $Str : undef ; 
}

sub getComponents
###############################################################################
#
# Input:	\%Config , \%MainConf 
#
# Return:	%CompList:
#			CompName	=> \%CompRec
#
#		%CompRec :
#		Logs -   \@Array - list of Log Files
#		StopProcess  - $String  - Stop commad of the process
#		Parameters   - \%ParamerInfo   {ParameterPath} -> Parameters Values
#
# Description: 
#
#
###############################################################################
{
    my $Conf=shift;
    ## my $Unit=shift;
    my $MainConf=shift;
    my $BabDir="/usr/cti/conf/babysitter";
    my (%Result,@AppList,$DirHd);
    my $Err=0;
    ### Read all Applicaton*.xml files from babysitter Dir  ####
    ## WrLog("Debug - Read Dirctory $BabDir ....");
    unless ( opendir($DirHd,$BabDir) )
    {
    	WrLog("Error - Fail to Read Dir $BabDir" );
    	$G_ErrorCounter++;
    	close($DirHd);
    	return undef;
    }
    my @FileList=grep(/Application.+.xml$/,readdir($DirHd));
    close($DirHd);
    #####   Search all components at Application xml files.
    foreach my $FileName (@FileList)
    {
    	my $XmlDoc=XML::LibXML->new()->parse_file("$BabDir/$FileName");
    	defined $XmlDoc or next;
    	my @AppNodes=$XmlDoc->documentElement()->findnodes("//Applications/ROW");
    	foreach my $AppXml (@AppNodes)
    	{
    	     my $CompName=$AppXml->getAttribute("Name");
    	     
    	     exists $$Conf{$CompName} or next ;
    	     WrLog("Info  - Component $CompName defined at file $FileName");
    	     #WrLog("Debug - Elemnt ROW:",$AppXml->toString());
    	     my $CmdStr=$AppXml->findvalue("//ROW[\@Name=\"$CompName\"]/LINUX/\@TerminationScript");
    	     unless ( $CmdStr )
    	     {
    	 		WrLog("Warning - Component $CompName - have no stop process procedure !");
    	 		next ;
    	     }
    	     exists $G_CLIParams{D} and WrLog("Debug - Insert to $CompName: StopProcess -> $CmdStr");
    	     $Result{$CompName}= { StopProcess => $CmdStr }
    	}
    }
    
    ####  Now check if all Components at configuration file had matching Application.xml file ...
    foreach my $CompName ( getSections($Conf) )
    {
    	exists $G_CLIParams{D} and WrLog("Debug - checkin component \"$CompName\"");
    	$CompName eq "Main.Config" and next;
    	if ( $CompName =~ /^(.+)-Files/ )
    	{
    	    my $TmpName=$1;
    	    my @FileList;
    	    foreach my $FileStr ( getSecContent($Conf,$CompName) )
    	    {
    	    	my $ExtarctName=ExtractUnit($FileStr,$$MainConf{Unit});
    	    	defined $ExtarctName and push(@FileList,$ExtarctName);
    	    }
    	    if (  @FileList )
    	    {
    	        exists $Result{$TmpName} or $Result{$TmpName}={};
    	        my $HashPointer=$Result{$TmpName};
    	        $$HashPointer{Logs}=\@FileList;
    	    }
    	} else  ## Component name ###
    	{
    	    exists $G_CLIParams{D} and WrLog("Debug  - Setting the component \"$CompName\" ...");
    	    my %TmpHash=ReadSections($Conf,$CompName);
    	    my %ParamHash;
    	    ###my $Counter=0;
    	    while ( my ($Parameter,$ValList) = each(%TmpHash) )
    	    {
    	    	my $TmpKey=ExtractUnit($Parameter,$$MainConf{Unit});
    	    	defined $TmpKey or next;
    	    	my @ConfValues=split(/,/,$ValList);
    	    	unshift(@ConfValues,"[$CompName]$Parameter");
    	    	$ParamHash{$TmpKey}=\@ConfValues;
    	    	###$Counter++;
    	    }
    	    $Result{$CompName}->{Parameters}=\%ParamHash;
    	} 
    }
    ###########   Check all component are well defined  ####
    while ( my ($CompName,$CompRec) = each(%Result) )
    {
    	my $ConfList=exists $$CompRec{Parameters} ? $$CompRec{Parameters} : {};
    	my $LogList=exists $$CompRec{Logs} ? $$CompRec{Logs} : [] ;
    	my $StopProcess=$$CompRec{StopProcess};
    	unless ( keys(%$ConfList) + @$LogList )
    	{
    	    WrLog("Info  - component $CompName should not participate at Log monitor at this $$MainConf{Unit} machine");
    	    delete $Result{$CompName};
    	    next;
    	}
    	@$LogList or WrLog("Warning - Component \"$CompName\" don't have any Logs list for $$MainConf{Unit} machine");
    	if ( keys(%$ConfList) )
    	{
    	    defined ($StopProcess) and next ;
			$$CompRec{StopProcess}="Error no Stop Process Defined at Babysitter";
    	    WrLog("Warning - No Stop Process found for component \"$CompName\"");
    	    ## $Err++;
    	    ## $G_ErrorCounter++;
    	}
    }
	$Err = ReadCompVals(\%Result,$MainConf);
    return $Err ? undef : %Result;
}

sub getUnit
{
    my $Conf=shift;
    my $FileName="/usr/cti/conf/babysitter/Babysitter.ini";
    my %BabysitterConf=LoadIniFile($FileName);
    my %Params=ReadSections(\%BabysitterConf,"General");
    return $Params{UnitType};
}

sub CreateXmlobj
{
    my $FileName=shift;
    WrLog("Info  - parse xml File $FileName");
    return -e $FileName ? XML::LibXML->new()->parse_file($FileName) : undef;
}

sub CreateIniobj
{
    my $FileName=shift;
    WrLog("Info  - parse ini File $FileName");
	my %Result=LoadIniFile($FileName);
    return \%Result;
}

sub CreateTxtobj
{
    my $FileName=shift;
    WrLog("Info  - parse Txt File $FileName");
    my @Content=ReadFile($FileName);
    return @Content ? \@Content : undef;
}

sub AddExecCmd
{
    my $ExecObj=shift;
    my $Cmd=shift;
    ref($$ExecObj{CmdList}) eq "ARRAY" or $$ExecObj{CmdList}=[];
    my $CmdList=$$ExecObj{CmdList};
    push(@$CmdList,$Cmd);
    return ;
}

sub CreateExeObj
###############################################################################
#
# Input:	$ExecGrouptype , \%MainConf 
#
# Return:	%ExcObj :
#		ExeFile  - The name of the ExecFile ( which will run all the commads
#			   at the background.
#		PIDFile  - The File which contain all the background PIDs
#		CmdList  - \@Array Array of all the commda to run
#
# Description: ExecGrouptype - is the Strind between cmd://(ExecGrouptype)//Command ..
#
#
###############################################################################
{
    my $ExecGroup=shift;
	my $ConfRec=shift;
	###    Map which Exec Group use which configuration parameters .... ####
	my %ExecMap=( PreReset	=>	["PreExecute","PrePId"] ,
				  PostReset	=>	["PostExecute","PostPId"] );
    unless ( exists $ExecMap{$ExecGroup} ) 
	{
		WrLog("Error - Unknown command type \"$ExecGroup\" - check configuration file",
			  sprintf("\t - Avaialble commad types: %s",join(',',keys(%ExecMap))));
	    $G_ErrorCounter++;
		return undef;
    }
	WrLog("Info  - Create Exec Object for $ExecGroup");
	exists $G_CLIParams{D} and WrLog("Debug - Create Exec obj for $ExecGroup:" ,
							 sprintf("\t - Exec File: %s (Taken from Conf{%s})",$$ConfRec{$ExecMap{$ExecGroup}->[0]},$ExecMap{$ExecGroup}->[0]));
	my %Result= ( ExeFile  => $$ConfRec{$ExecMap{$ExecGroup}->[0]} ,
    		      PIDFile  => $$ConfRec{$ExecMap{$ExecGroup}->[1]} ,
    		      CmdList  => [] );
    my @ClearList;
    -e $Result{ExeFile} and push(@ClearList,"rm -f $Result{ExeFile}");
    $G_ErrorCounter += RunCmds(@ClearList);
    return \%Result;
}

sub getXmlParam
{
    my $XmlDoc=shift;
    my $Xpath=shift;
    $Xpath =~ s/\\([\$=\*\+])/$1/g ; 
    my $ErrFlag=eval("\$XmlDoc->find(\$Xpath)");
    defined $ErrFlag and return $XmlDoc->findvalue($Xpath);
    WrLog("Error - Ilegal Xpath \"$Xpath\". check configuration file");
    $G_ErrorCounter++;
    return undef;
}

sub setXmlParam
{
    my $XmlDoc=shift;
    my $Xpath=shift;
    my $XmlVal=shift;
    my $Err=0;
    $Xpath =~ s/\\([\$=\*\+])/$1/g ; 
    WrLog("Info - Update xml $Xpath = $XmlVal");
    ##my $OldVal=$XmlDoc->findvalue($Xpath);
    ## WrLog("Info - Saving Old Value $OldVal - $Xpath");
    my $Node=$XmlDoc->findnodes($Xpath)->[0];
    if ( $Node->nodeType() == XML_ELEMENT_NODE )
    {
    	exists $G_CLIParams{D} and WrLog("Debug - setting $Xpath as element");
    	$Node->appendTextNode($XmlVal);
    }elsif ( $Node->nodeType() == XML_ATTRIBUTE_NODE )
    {
    	exists $G_CLIParams{D} and WrLog("Debug - setting $Xpath as Attributr");
    	$Node->setValue($XmlVal);
    } elsif ( $Node->nodeType() == XML_TEXT_NODE )
    {
    	$Node->setData($XmlVal);
    } else
    {
    	WrLog(sprintf("Error - Unknown / suported node Type %d -> $Xpath", $Node->nodeType()));
    	$G_ErrorCounter++;
    	$Err++;
    }
    return $Err;
}

sub getIniParam
{
    my $IniDoc=shift;
    my $IniPath=shift;
    
    unless ( $IniPath=~/\[(.+?)\](.+)$/ )
    {
    	WrLog("Error - Syntax Error Ilegal iniFile Path $IniPath");
    	$G_ErrorCounter++;
    	return undef;
    }
    my ($Section,$Param)=($1,$2);
    my %SecHash=ReadSections($IniDoc,$Section);
    return $SecHash{$Param};
}

sub setIniParam
{
    my $IniDoc=shift;
    my $IniPath=shift;
    my $iniVal=shift;
    exists $G_CLIParams{D} and WrLog("Debug - Update Ini $IniPath = $iniVal");
    unless ( $IniPath=~/\[(.+?)\](.+)$/ )
    {
    	WrLog("Error - Syntax Error Ilegal iniFile Path $IniPath");
    	return undef;
    }
    my ($Section,$Param)=($1,$2);
    SetSection($IniDoc,$Section,($Param => $iniVal) );
    return 0;
}

sub saveXmlFile
{
    my $XmlObj=shift;
    my $FileName=shift;
    return -e $FileName ? UpdateFile($FileName,$XmlObj->toString()) : WriteFile($FileName,$XmlObj->toString());
}

sub saveTxtFile
{
	my $TxtObj=shift;
	my $FileName=shift;
	return UpdateFile($FileName,@$TxtObj);
}

sub saveExec
{
	my $ExecObj=shift;
	my $ExecGroup=shift;
	my $CompObj=shift;
	$$CompObj{$ExecGroup}=$ExecObj;
	return 0;
}

sub findTxtPattern
{
    my $TxtArray=shift;
    my $ChSep=shift;
    my $Triger=join('|',@_);
    my %Result;
    foreach (@_)
    {
    	$Result{$_}=[];
    }
    for ( my $Indx=0; $Indx <= $#$TxtArray ; $Indx++ )
    {
    	$$TxtArray[$Indx] =~ /(^|\s)($Triger)(\s|$ChSep|$)/ or next ;
    	push(@{$Result{$2}},$Indx);
    	exists $G_CLIParams{D} and WrLog("Debug - Find $2 at Line $Indx");
    }
    return %Result;
}

sub ParseTxtParam
{
    my $ParamStr=shift;
    my %Result = ( 's' => '=' );
    my $TxtOptions;
    $ParamStr =~ s/^\[(.+?)\]// and $TxtOptions=$1;
    while ( $TxtOptions =~ s/^([ablvsr])(\S+|.)\s*// )
    {
    	$Result{$1}=$2;
    	exists $G_CLIParams{D} and WrLog("Debug - Insert Option $1 => \"$2\"");
    }
    $Result{Name}=$ParamStr;
    return %Result;
}

sub getTxtParam
{
    my $TxtArray=shift;
    my $Param=shift;
    my %TxtOp=ParseTxtParam($Param);
    my %TrigerPlace=findTxtPattern($TxtArray,$TxtOp{s},$TxtOp{Name});
    my $Result=$$TxtArray[$TrigerPlace{$TxtOp{Name}}->[-1]];
    $Result =~ s/^.*$TxtOp{Name}(\s*?)$TxtOp{s}//;
    return $Result;
}

sub setTxtParam
{
    my $TxtArray=shift;
    my $Param=shift;
    my $TxtVal=shift;
    my %TxtOp=ParseTxtParam($Param);
    my $Err=0;
    my ($NewVal,$Tune,$TxtOptions);
    ### ToDo Parse Operands ...
    my @Trigers= ( $TxtOp{Name} );
    exists $TxtOp{b} and push(@Trigers,$TxtOp{b});
    exists $TxtOp{a} and push(@Trigers,$TxtOp{a});
    my %TrigerPlace=findTxtPattern($TxtArray,$TxtOp{s},@Trigers);
    #my $OldVal=$TrigerPlace{$Param}->[-1];
    #$OldVal =~ s/$Param(\s*?)$TxtOp{s}// ;
    my $Triger=$TxtOp{Name};
    my ($MatcLine,$NextLine,$LastLine);
    if ( $#{$TrigerPlace{$Triger}} < 0 )
    {   ### Parameter not exist at file add it to file
        exists $TxtOp{r} and return $Err;
        exists $G_CLIParams{D} and WrLog("Debug - Parameter $Triger not exist at file create new one.");
    	if ( exists $TxtOp{a} and $#{$TrigerPlace{$TxtOp{a}}} >=0 )
    	{
    	    $MatcLine=$TrigerPlace{$TxtOp{a}}->[-1];
    	    exists $G_CLIParams{D} and WrLog("Debug - Add $TxtOp{Name} at Line $MatcLine");
    	    
    	} elsif ( exists $TxtOp{b} and $#{$TrigerPlace{$TxtOp{b}}} >=0 )
    	{
    	    $MatcLine=$TrigerPlace{$TxtOp{b}}->[-1]-1;
    	    exists $G_CLIParams{D} and WrLog("Debug - Add $TxtOp{Name} at Line $MatcLine");
    	} else
    	{
    	    $MatcLine=$#$TxtArray + 1;
    	}
    	my $NewLine="$TxtOp{Name}$TxtOp{s}$TxtVal";
    	$LastLine=$#$TxtArray;
    	$NextLine=$MatcLine+1;
    	if ( $MatcLine < 0 )
    	{
    	   unshift(@$TxtArray,$NewLine);
    	} elsif ( $NextLine > $LastLine )
    	{
    	     push(@$TxtArray,$NewLine);
    	} else
    	{
    	   my @NewContent=(@$TxtArray[0-$MatcLine],$NewLine,@$TxtArray[$NextLine-$LastLine]);
    	   @$TxtArray=@NewContent;
    	}
    } else
    {   ## Parameter already exists at file
        $MatcLine=$TrigerPlace{$Triger}->[-1];
        exists $G_CLIParams{D} and WrLog("Debug - update $Triger at Line $MatcLine.");
        if ( exists $TxtOp{v} )
        {
        	$$TxtArray[$MatcLine]=~/^(.*?$Triger\s*$TxtOp{s}\s*)(\S.+|$)/ ;
        	$NextLine = $1;
        	$LastLine = $2 ; 
        	my @ValList=split(/$TxtOp{v}/,$LastLine);
        	unless ( grep(/^$TxtVal$/,@ValList) )
        	{
        	     $LastLine= exists $TxtOp{l} ? "$LastLine$TxtOp{v}$TxtVal" : "$TxtVal$TxtOp{v}$LastLine" ;
        	     $$TxtArray[$MatcLine]="$NextLine$LastLine";
    	        }
    	 } elsif ( exists $TxtOp{r} )
    	 {
    	 	foreach $MatcLine ( @{$TrigerPlace{$Triger}} )
    	 	{
    	 	    $$TxtArray[$MatcLine]=~ s/$Triger/$TxtVal/;
    	 	}
    	 } else
    	 {
    	      $$TxtArray[$MatcLine]=~s/($Triger\s*$TxtOp{s}\s*)(\S.+|$)/$1$TxtVal/ ;
    	 }
    }
    return $Err;
}

sub NullOPerand
{
    exists $G_CLIParams{D} and WrLog("Debug - Null Command do nothing ...");
}

sub SetConfigCompVals #\%compRec , \%Conf , $Mode
{
    my $CompRec=shift;
    my $Conf=shift;
	my $Mode=shift;
    my $Err=0;
	exists $G_CLIParams{D} and WrLog("Debug - Going To update configuration File  $$Conf{FileName}");
    while ( my ($CompName,$CompRec) = each(%$CompRec) )
    {
    	WrLog("Info  - Update Component $CompName values at configuration");
		while ( my ($ParamPath,$ParamVals)  = each(%{$$CompRec{Parameters}})) 
    	{
			 $ParamPath =~ /cmd:\/\// and next;
			 exists $G_CLIParams{D} and WrLog("Debug - SetConfigCompVals $ParamPath Value: $ParamVals");
			 ## my @ParamList=split(/,/,$ParamVals);
    	     exists $G_CLIParams{D} and WrLog("Debug - Update at Configuration file @$ParamVals");
			 my $ValStr = $Mode eq "Install" ? "$$ParamVals[1],$$ParamVals[-1]" : join(',',@$ParamVals[1..2]) . ",$$ParamVals[-1]";
    	     $Err += setIniParam($Conf,$$ParamVals[0],$ValStr);
			 exists $G_CLIParams{D} and WrLog("Debug - Next Loog ....");
    	}
    }
	exists $G_CLIParams{D} and WrLog("Debug - Out of the Loop ! Going to Update the configuration file $$Conf{FileName}");
    if ( $Err )
    {
    	WrLog("Error  - Not all configuration valuse could be set Skip configurtion Update");
    	return $Err;
    } else
    {
		exists $G_CLIParams{D} and WrLog("Debug - Updating file $$Conf{FileName}");
    	return UpDateIniFile($Conf);
    }
}

sub SetCompConfig #\%compRec , Mode , \%Conf
{
    my $CompRec=shift;
    my $Mode=shift;
    my $Conf=shift;
    my $Err=0;
    my %SetMode= (  Debug   =>  1 ,
    		        "Last"  => -2 ,
    		        Restore => 2 ,
    		        Install => -1 );
    my %SaveMethod = ( "XML::LibXML::Document"	=>  \&saveXmlFile  ,
	                   "HASH"		=>  \&UpDateIniFile ,
    				   "ARRAY"		=>  \&saveTxtFile ,
					   "Exec"		=>	\&saveExec );
    my %FileMap;
    exists $SetMode{$Mode} or WrLog("Error - unknown mode \"$Mode\""), return 1;
    ####		      Set , Create , Get , save
    my %FTypeMap = ( xml  => [\&setXmlParam,\&CreateXmlobj] ,
    		         ini  => [\&setIniParam,\&CreateIniobj] ,
    		         txt  => [\&setTxtParam,\&CreateTxtobj] ,
    		         cmd  => [\&AddExecCmd,\&CreateExeObj]);
    my $PrefixPattern=join("|",keys(%FTypeMap));
    while ( my ($CompName,$CompRec) = each(%$CompRec) )
    {
    	WrLog("Info  - Update Configuration files of component $CompName");
    	while (  my ($ParamPath,$ParamVals) =   each(%{$$CompRec{Parameters}}) )
    	{
    	     if ( $ParamPath =~ /($PrefixPattern):\/\/(.+?)\/\/(.+)$/ )
    	     {
    	     	my $FType=$1;
    	     	my $FPath=$2;
    	     	my $PPath=$3;
    	     	exists $G_CLIParams{D} and WrLog("Debug - Check if there is already File obj for ($FType):\"$FPath\"");
    	     	exists $FileMap{$FPath} or $FileMap{$FPath}=$FTypeMap{$FType}->[1]->($FPath,$Conf);
    	     	my $FileObj=$FileMap{$FPath} ; 
				unless ( ref($FileObj) ) 
				{
					WrLog("Error - Fail to create Obj for $FPath ($FType)");
					$G_ErrorCounter++;
					next;
				}
    	     	exists $G_CLIParams{D} and WrLog("Debug - $CompName : Update $FPath , Parameter $PPath to $$ParamVals[$SetMode{$Mode}] ($FType)");
    	     	$Err += $FTypeMap{$FType}->[0]->($FileObj,$PPath,$$ParamVals[$SetMode{$Mode}]);
    	     } else
    	     {
    	     	WrLog("Error - Unknown parameter configuration: $ParamPath");
    	     	$Err++;
    	     	$G_ErrorCounter++;
    	     }
    	}
    }
    unless ( $Err )
    {
    	WrLog("Info  - Save changes at Components configuration files.");
    	while ( my ($FileName,$FileObj) = each(%FileMap) )
    	{
    	     ## WrLog("Debug - Check if File \"$FileName\" shoulld be update ($FileObj)");
    	     my $Type=ref($FileObj) or next ;
			 $Type eq "HASH" and exists $$FileObj{ExeFile} and $Type="Exec";
    	     if ( exists $SaveMethod{$Type} )
    	     {
    	     	WrLog("Info  - Saving/Update $FileName");
    	     	$Err += $SaveMethod{$Type}->($FileObj,$FileName,$CompRec);
    	     } else
    	     {
    	     	WrLog("Error - Unknown object Type \"$FileObj\" save method");
    	     	$Err++;
    	     }
    	}
    }
    return $Err;
}

sub ReadCompVals #\%CompRec,\%MainConf
{
    my $CompRecList=shift;
    ## my $Conf=shift;
    my $Err=0;
    ### CreateExeObj($MainConf{PreExecute},$MainConf{PrePId});
    my %FTypeMap = ( xml  => [\&CreateXmlobj,\&getXmlParam] ,
    		     ini  => [\&CreateIniobj,\&getIniParam] ,
    		     txt  => [\&CreateTxtobj,\&getTxtParam] ,
    		     cmd  => [\&NullOPerand,\&NullOPerand]);
    		     ## cmd  => [\&AddExecCmd,\&ErrCmdSyntax,\&NullOPerand]);
    my $PrefixPattern=join("|",keys(%FTypeMap));
    my %FileMap;
    while ( my ($CompName,$CompRec) = each(%$CompRecList) )
    ## foreach my $CompName ( getSections($Conf) )
    {
    	WrLog("Info  - Read Configuration values of $CompName");
    	while ( my ($ParamPath,$ParamVal) = each(%{$$CompRec{Parameters}}) )
    	{
    	    if ( $ParamPath =~ /($PrefixPattern):\/\/(.+?)\/\/(.+)$/ )
    	     {
    	     	my $FType=$1;
    	     	my $FPath=$2;
    	     	my $PPath=$3;
				$FileMap{$FPath} or $FileMap{$FPath}=$FTypeMap{$FType}->[0]->($FPath);
    	     	my $FileObj=$FileMap{$FPath} ;
				unless ( defined $FileObj ) 
				{
					WrLog("Error - Fail to read / open / parse $FPath (type $FType)");
					$Err++;
    	     		$G_ErrorCounter++;
					next ;
				}
    	     	my $LastVal = $FTypeMap{$FType}->[1]->($FileObj,$PPath);
    	     	my @CompVals=(@$ParamVal[0..3],$LastVal);
    	     	$$CompRec{Parameters}->{$ParamPath}=\@CompVals;
				exists $G_CLIParams{D} and WrLog("Debug - set Component values: $ParamPath => @CompVals");
    	     } else
    	     {
    	     	WrLog("Error - Unknown parameter configuration: $ParamPath");
    	     	$Err++;
    	     	$G_ErrorCounter++;
    	     	## return 1;
    	     }
    	 }
    }
    return $Err;
}

sub GrapLogs #\%CompList , $TargetFile
{
    my $CompList=shift;
    my $TargetFile=shift;
    ## my $Zip=Archive::Zip->new();
    my $Err;
    my @CmdList = ("rm -f $TargetFile");
    my $TmpStr=$G_CLIParams{LogFile};
    $TmpStr =~ s/(^|,)-(,|$)// ;
    my @PathList=split(/,/,$TmpStr);
    while ( my ($CompName,$CompRec) = each(%$CompList) )
    {
    	WrLog("Info - gadering all $CompName log files ...");
    	push(@CmdList,"mkdir -p /tmp/$CompName","rm -f /tmp/$CompName/*");
		push(@PathList,"/tmp/$CompName/*");
    	foreach my $FilePath ( @{$$CompRec{Logs}} )
    	{
    	    my $FileName= $FilePath ;
    	    $FileName =~ s/^.+\/// ;
    	    push(@CmdList,"cp $FilePath /tmp/$CompName");
    	}
    	##$Err += RunCmds(@CmdList);

    }
    my $ZipCmd=sprintf("zip -q9 $TargetFile %s",join(" ",@PathList));
    $Err += RunCmds(@CmdList,$ZipCmd,"chmod 666 $TargetFile");
    return $Err ;
}

sub RunBackground  ## \%ExecObj
{
    my $ExecObj=shift;
    my $ExecFile=$$ExecObj{ExeFile};
    my $PIdFile=$$ExecObj{PIDFile};
    my $ExecCmds=$$ExecObj{CmdList};
    
    RunCmds("rm -f $$ExecObj{PIDFile} $$ExecObj{ExeFile}") and return 1;
    $#$ExecCmds < 0 and return 0;
    my @ExecLines= ("#!/bin/bash","");
    foreach my $Iter (@$ExecCmds)
    {
    	my $ExecLine = $Iter =~ /\s*\&\s*$/ ? $Iter : "$Iter &";
    	## $Iter =~ /\s*\&\s*$/ or $Iter .= " &";
    	push(@ExecLines,$ExecLine,"echo \"\$! - $Iter\" >> $PIdFile");
    }
    WriteFile($ExecFile,@ExecLines);
    RunCmds("chmod +x $ExecFile");
    my $Pid=fork();
    if ( $Pid )
    {
    	sleep(3);
    	my $Err=$G_ErrorCounter;
    	my @Lines=ReadFile($PIdFile);
    	$G_ErrorCounter > $Err and WrLog("Error - Fail to read $PIdFile. check if all the processes r up ...");
    	### Update configuration file ##
    	## RunCmds("kill -9 $Pid");
    } else
    {
    	exec($ExecFile);
    }
    return 0;
}

sub getPIdList #@List of PIDs
{
    my @InputList=@_;
    my @Result;
	my %ValidateMap;
	@InputList or return;
    foreach my $Line (@InputList)
    {
    	unless ( $Line =~ s/^(\d+)(\s-\s+)?// )
    	{
    	      WrLog("Error - Ilegel line Input:",
    	      	    "\t - $Line","\t - skip This line ...");
    	      $G_ErrorCounter++;
    	      next;
    	}
    	my $PID=$1;
		$Line =~ s/\s*[><&\|].*// ;
		$ValidateMap{$PID}=$Line;
	}
    my $PIdStr=join(' ',keys(%ValidateMap));
	my @RunningList=`ps u $PIdStr`;
	## WrLog("Debug - getPIdList - Input:",@InputList,"--Debug Found Out:",@RunningList,"","");
	shift(@RunningList);  ## Remove Title  ##
	my $PID;
	foreach my $Line  ( @RunningList ) 
	{
		$PID=0;
		chomp $Line;
		exists $G_CLIParams{D} and WrLog("Debug - Analyze : \"$Line\"");
		if ( $Line =~ s/((\S+)\s+){2}((\S+)\s+){6}((\S+)\s+){2}// ) 
		{
			$PID=$2;
			my $State=$4;
			$State =~/^[SR]/ or $PID=0;
			exists $G_CLIParams{D} and WrLog(sprintf("Debug - %s : \"$Line\"",$PID ? "Add $PID" : "Ignore Line"));
		}
		exists $G_CLIParams{D} and WrLog("Debug - Validte the prtocess is $ValidateMap{$PID}");
		exists $ValidateMap{$PID} or next;
		$ValidateMap{$PID} or push(@Result,$PID),next;
		$ValidateMap{$PID} =~ $Line and push(@Result,$PID);
    }
	## WrLog("Debug - getPIdList Result:",@Result);
    return @Result;
}

sub StopBackground ### \%ExecObj
{
    my $ExecObj=shift;
	my $Err=0;
    my @PIdFile=();
    if ( -e $$ExecObj{PIDFile} )
    {
    	@PIdFile=ReadFile($$ExecObj{PIDFile});
    } else
    {
    	WrLog("Warning - PID File \"$$ExecObj{PIDFile}\" missing. That means no process will be killed");
    }
	while ( @PIdFile ) 
	{
		  @PIdFile=getPIdList(@PIdFile);
		  @PIdFile and TraceKill(@PIdFile);
	}
    return $Err;
}

sub StopComponents   ###(\%ComponentsList , %Options);
{
    my $CompList=shift;
    my %Options= @_;
    my @BabysitterLines;
    WrLog("Info  - Start stoping relevant componenets ...");

    #### should stop simultani all process (using threads)
    my @Thread;
	my $Mask=join("|",keys(%$CompList));
    while ( my ($CompName,$CompRec) = each(%$CompList) )
    {
		$$CompRec{StopProcess} or next;
		my $Cmd="/usr/cti/babysitter/MamCMD restart $CompName";
    	WrLog("Info  - Stoping $CompName ..."); ## ,"Excuting - $$CompRec{StopProcess}");
    	##system("$$CompRec{StopProcess} &") and WrLog("Error Excuting $$CompRec{StopProcess}");
		system("$Cmd &") and WrLog("Error - $Cmd");
    }
    sleep(5);
	my $Flag=$Options{StartTimeOut} - 5;
	####  Check which Component have not start again ###
    while ( $Flag > 0 )
    {
		sleep(1);
    	@BabysitterLines=`MamCMD -d`;
		my @AllTaks=grep(/^($Mask)/,@BabysitterLines);
		grep(/Down\s+\-/,@AllTaks) or $Flag=-10;
    	$Flag--;
    }
    unless ( $Flag < 0 )
    {	####  Find the process that still don't up ###
		my @DownTasks=grep(/^($Mask)\s+Down\s\-/,@BabysitterLines);
		foreach my $TaskName ( @DownTasks ) 
		{
			$TaskName =~ s/^(\S+)\s.+$/$1/ ;
			system("/usr/cti/babysitter/MamCMD start $TaskName &") and WrLog("Error  - Starting via babysitter $TaskName");
		}
	}
	$Flag = $Options{RestartTimeOut} ;
	while ( $Flag > 0 )
    {
		sleep(1);
    	@BabysitterLines=`MamCMD -d`;
		my @AllTaks=grep(/^($Mask)/,@BabysitterLines);
		grep(/Down\s+/,@AllTaks) or $Flag=-10;
    	$Flag--;
		$Flag % 10 or WrLog("Debug - waiting all process go up ....");
    }

	unless ( $Flag < 0 ) 
	{
		WrLog("Error - Babysitter Retart time out");
		my @AllTaks=grep(/^($Mask)\s+Down/,@BabysitterLines);
		WrLog("\t - The following Task Still Down:",@AllTaks,"");
		return 1;
	}
    return 0
}

sub InstallKit # \%ComponentsList , \%MainConf , [\%IniConfig]
{
    my $CompList=shift;
    my $ConfParams=shift;
    my $MainIniFile=shift;
    ## my $Err=ReadCompVals($CompList);
	## exists $G_CLIParams{D} and WrLog("Debug - Install Kit Function:  $$MainIniFile{FileName} !!!!","","");
	my $Err += SetConfigCompVals($CompList,$MainIniFile,"Install");
	## exists $G_CLIParams{D} and WrLog("Debug - Install (After) Function:  $$MainIniFile{FileName} !!!!","","");
    ## $Err += SetCompConfig($CompList,"Last",$MainIniFile);

    return $Err;
}
sub RestoreKit # \%ComponentsList , \%MainConf , [\%IniConfig]
{
    my $CompList=shift;
    my $ConfParams=shift;
    my $MainIniFile=shift;
	## my $Err=ReadCompVals($CompList);
    return SetCompConfig($CompList,"Restore",$ConfParams);
}
sub SetLogs #    \%ComponentsList , \%MainConf , [\%IniConfig]
{
    my $CompList=shift;
    my $ConfParams=shift;
    my $MainIniFile=shift;
    my $Err=0;
	## $Err=ReadCompVals($CompList);
    $Err += SetCompConfig($CompList,"Debug",$ConfParams);
	$Err += SetConfigCompVals($CompList,$MainIniFile,"Last");
    ##	my $PostPointer=$$CompList{PostReset};
	### delete $$CompList{PostReset};
	$Err += ClearLog($CompList,$ConfParams,$MainIniFile);
	$Err += StopBackground($$CompList{PreReset});
	$Err += StopBackground($$CompList{PostReset});
	if ( exists $$CompList{PreReset} ) 
	{
		$Err += RunBackground($$CompList{PreReset});
	} elsif ( exists $G_CLIParams{D} ) 
	{
		WrLog("Debug - No PreReset Commads have found at configuration");
	}
	$Err += StopComponents($CompList,%$ConfParams);
	if ( exists $$CompList{PostReset} ) 
	{
		$Err += RunBackground($$CompList{PostReset});
	} elsif ( exists $G_CLIParams{D} ) 
	{
		WrLog("Debug - No PostReset Command have found at Configuration");
	}
    return $Err ;
}
sub SetNormal #  \%ComponentsList , \%MainConf , [\%IniConfig]
{
    my $CompList=shift;
    my $ConfParams=shift;
    my $MainIniFile=shift;
    my $Err=0;
	## $Err=ReadCompVals($CompList);
    $Err += SetCompConfig($CompList,"Last",$ConfParams);
    $Err += StopComponents($CompList,$ConfParams);
	$Err += StopBackground($$CompList{PreReset});
    return $Err + GatherLogs($CompList,$ConfParams,$MainIniFile);
}
sub ClearLog #   \%ComponentsList , \%MainConf , [\%IniConfig]
{
    my $CompList=shift;
    my $ConfParams=shift;
    my $MainIniFile=shift;
    my $Err=0;
   #####  Clear Old logs   ########
   while ( my ($CompName,$CompRec) = each(%$CompList) )
   {
   	   exists $$CompRec{Logs} or next;
   	   WrLog("Info  - clear logs of $CompName");
	   my $CmdStr=sprintf("sh -c \'for fname in %s ; do if [ -e \$fname ];then >\$fname ;fi; done\'",join(" ",@{$$CompRec{Logs}}));
   	   # $Err += RunCmds("rm -f " . join(" ",@{$$CompRec{Logs}}) );
	   $Err += RunCmds($CmdStr);
   }
   ###### Todo which Procees I should Start !!!! ????
   ###### Todo which Procees I should Kill !!!! ????
    $Err += StopBackground($$CompList{PostReset});
   exists $$CompList{PostReset} and $Err += RunBackground($$CompList{PostReset});
   return $Err;
}
sub GatherLogs # \%ComponentsList , \%MainConf , [\%IniConfig]
{
    my $CompList=shift;
    my $ConfParams=shift;
    my $MainIniFile=shift;
    my $Err=0;
    #### Todo  Check which cmds type do I have .....  ###
    $Err += StopBackground($$CompList{PostReset});
    $Err += GrapLogs($CompList,$$ConfParams{Archfile});
	$Err += ClearLog($CompList,$ConfParams,$MainIniFile);
    $Err and $G_ErrorCounter++;
    return $Err;
}

sub BuildRebort # \%ComponentsList , \%MainConf , [\%IniConfig]
{
	my $CompList=shift;
    my $ConfParams=shift;
    my $MainIniFile=shift;
    my $Err=0;
	my $HostName=`hostname`;
	my $LocalIP=`hostname -i`;
	chomp $HostName ;
	chomp $LocalIP;
	my ($TotalCounter,$DebugCounter,$FactoryCounter,%FileMap);
	my @Report=("Report for : $LocalIP ($HostName)",
				"Machine Type: $$ConfParams{Unit}");
	while ( my ($CompName,$CompRec) = each(%$CompList) ) 
	{
		## $CompName =~ /PostReset|PreReset/ and next;
		## WrLog("Debug - Analyze Component $CompName");
		 while ( my ($ParamPath,$ParamVal) = each(%{$$CompRec{Parameters}}) )
    	{
			 $ParamPath =~ m/(\w+?):\/\/(.+?)\/\/(.+)/ or next ;
			 my $FType=$1;
			 my $FileName=$2;
			 $ParamPath=$3;
			 if ( lc($FType) eq "cmd" ) 
			 {
				 exists $FileMap{$FileName} or $FileMap{$FileName}=CreateExeObj($FileName,$ConfParams);
				 next;
			 }
			 $TotalCounter++;
			 my $State;
			 if ( $$ParamVal[-1] eq $$ParamVal[1] ) 
		     {
				$DebugCounter++;
				$State="Debug";
			 }
			 if ( $$ParamVal[-1] eq $$ParamVal[2] ) 
			 {
				 $State .= $State ? " or Factory" : "Factory";
				 $FactoryCounter++;
			 }
			 my @RepLine=($ParamPath,$State,$$ParamVal[-1]);
			 exists $FileMap{$FileName} or $FileMap{$FileName}=[];
			 push(@{$FileMap{$FileName}},\@RepLine);
			 ## $FileName =~ /PostReset|PreReset/ and WrLog("Debug - File $FileName at omponent $CompName");
		}
	}
	my $TotalState="Unknown";
	if ( $TotalCounter == $DebugCounter ) 
	{
		$TotalState="Debug";
	} elsif ( $TotalCounter == $FactoryCounter ) 
	{
		$TotalState="Factory (Normal)";
	}
	push(@Report,"Machine Logger State: $TotalState","Parameters Satus Details:");
	my @RunningProcess;
	while ( my ($FName,$Lines) = each(%FileMap) ) 
	{
		if ( ref($Lines) =~ /HASH/i ) 
		{
			WrLog("Debug - Check Running Process ...");
			if ( -e $$Lines{PIDFile} )
			{
    			my @PIdFile=ReadFile($$Lines{PIDFile});
				@PIdFile=getPIdList(@PIdFile);
				my $TmpCount=@PIdFile;
				exists $G_CLIParams{D} and WrLog("Debug - $TmpCount process still Running.");
				if ( @PIdFile ) 
				{
					my $Cmd=sprintf("ps u %s",join(' ',@PIdFile));
					@PIdFile=`$Cmd`;
					chomp(@PIdFile);
					@RunningProcess and shift(@PIdFile);
					push(@RunningProcess,@PIdFile);
				}
			} 
			next ;
		}
		push(@Report,"File $FName :");
		push(@Report,sprintf("%-75s %-17s Value","Parameter / Xpath","State"));
		foreach my $Row (@$Lines) 
		{
			push(@Report,sprintf("%-75s %-17s ($$Row[2])",$$Row[0],$$Row[1]));
		}

	}
	if ( @RunningProcess ) 
	{
		push(@Report,"Running Process:",@RunningProcess);
	}
	WrLog("",@Report,'-' x 100);
	$Err += WriteFile($$ConfParams{ReportFile},@Report);
	foreach my $LogFile (split(/,/,$G_CLIParams{LogFile})) 
	{
		$LogFile =~ /^\-/ and next;
		$Err += RunCmds("chmod 666 $LogFile","chmod 666 $$ConfParams{ReportFile}");
	}
	return $Err;
}

sub ReadConfig
{
    my $IniRec=shift;
    my %MainConf=ReadSections($IniRec,"Main.Config");
	my @DArr=localtime();
	my $DateStr=sprintf("%4d_%02d_%02d_%02d%02d%02d",$DArr[5]+1900,$DArr[4]+1,$DArr[3],$DArr[2],$DArr[1],$DArr[0]);
    my %Result = ( PreExecute	=> "/tmp/PreReset.sh", 
                   PrePId	=> "/tmp/PreReset.PID",
     	           PostExecute	=> "/tmp/PostReset.sh",
     	           PostPId	=> "/tmp/PostReset.PID",
				   ReportFile => "/tmp/Report.txt" ,
		           DownLoadFolder => "/tmp/LogMonitor/Download" ,
				   Date		=> $DateStr ,
				   RestartTimeOut	=> 90 ,
				   StartTimeOut		=> 20 ,
     	           %MainConf ,
				   %G_CLIParams );
   if ( exists $G_CLIParams{Remote} ) 
   {
	   length ($G_CLIParams{Remote}) > 0 and $Result{MachineList}=$G_CLIParams{Remote};
   }
   ### Modify Macros and executins #

   while ( my ($PName,$PVal) = each(%Result) ) 
   {
	   my $Mem=$PVal;
	   while ( $PVal =~ s/\`(.+?)\`/#ExecReplace#/ ) 
	   {
		   my $Tmp=`$1`;
		   chomp $Tmp;
		   exists $G_CLIParams{D} and WrLog("Debug - Result of $PName is \"$Tmp\"");
		   $PVal =~ s/#ExecReplace#/$Tmp/;
	   }
	   while ( $PVal =~ s/%\$(.+?)%/#ParamReplace#/ ) 
	   {
		   my $Tmp=exists $Result{$1} ? $Result{$1} : undef ;
		   $PVal =~ s/#ParamReplace#/$Tmp/ ;
	   }
	   $Mem eq $PVal or $Result{$PName}=$PVal;
   }
   $Result{Unit} or $Result{Unit}=getUnit($IniRec);
   return %Result;
}

sub getOperation
{
    my $Flag=shift || undef;
    my $Err;
    my @Result;
    my %OpList = ("Install" => ["Install",\&InstallKit,\&CheckTotalStatus],
    		  "Restore" => ["Restore",\&RestoreKit,\&CheckTotalStatus],
    		  "SetLog"  => ["SetLog",\&SetLogs,\&CheckTotalStatus]  ,
    		  "SetNormal" => ["SetNormal",\&SetNormal,\&CollectAllArchives] ,
    		  "ClearLogs" => ["ClearLogs",\&ClearLog,\&CheckTotalStatus] ,
    		  "GatherLogs" => ["GatherLogs",\&GatherLogs,\&CollectAllArchives] ,
		      "Report"	=> ["Report",\&BuildRebort,\&CollectReports]);
    $Flag and return keys(%OpList);
    while ( my ($OpName,$OpArray) =  each(%OpList) )
    {
    	exists $G_CLIParams{$OpName} or next;
    	if ( @Result )
    	{
			$Err or $Err=$Flag;
    	    WrLog("Error - More than one operation request !. $OpName,$Err");
    	    $Err .= ",$OpName";
    	    $G_ErrorCounter++;
    	} else 
    	{
    	    @Result=@$OpArray;
			$Flag=$OpName;
    	}
    }
	unless ( $Flag ) 
	{
		WrLog("Error - Missing operation commad - see usage");
		$Err++;
		$G_ErrorCounter++;
	}
    return $Err ? undef : @Result;
}

sub CollectAllArchives  #\%MainConf,\%MachineRec,\%MachineRec ....
{
	my $Conf=shift;
	my @RemoteList=@_;
	my %ZipComp;
	
	WrLog("Info  - Start to collect Archive Files from remote machines ...");
	my $Err=RunCmds("rm -rf $$Conf{DownLoadFolder}");
	foreach my $PRec (@RemoteList) 
    {
	   my @TmpList=ReadFile($$PRec{LogFile});
	   my @ZipList=grep(/Execute:.+zip/,@TmpList[-10..-1]);
	   $ZipList[-1] =~ /((\S+)\s+){4}/ and $$PRec{ZipFile}=$2;
	   my %TmpRec;
	   if ( exists $$PRec{ZipFile} ) 
	   {
		    my $ZipName=$$PRec{ZipFile};
			$ZipName =~ s/.+\///;
			$G_ErrorCounter += RunCmds("mkdir -p $$Conf{DownLoadFolder}/$$PRec{Machine}");
			$$PRec{ExpCmd}="expect /usr/cti/ServiceKit/copy.tcl $$PRec{Machine}:$$PRec{ZipFile}  $$Conf{DownLoadFolder}/$$PRec{Machine}/$ZipName";
			%TmpRec = ( Logs => ["$$Conf{DownLoadFolder}/$$PRec{Machine}/$ZipName",$$PRec{LogFile}] );
			$$PRec{LogFile} .= ".cp";
			
	   } else
	   {
		   WrLog("Error - Fail to find $$PRec{Machine} zip file ...");
		   $G_ErrorCounter++;
		   $Err++;
		   delete $$PRec{ExpCmd};
		   %TmpRec = ( Logs => [$$PRec{LogFile}] );
	   }
	   $ZipComp{$$PRec{Machine}}=\%TmpRec;
	}
	$Err += RunExpect($Conf,@RemoteList);
	return GrapLogs(\%ZipComp,$$Conf{TotalZip});
}

sub CollectReports  #\%MainConf,\%MachineRec,\%MachineRec ....
{
	my $Conf=shift;
	my @RemoteList=@_;
	my %ZipComp;
	WrLog("Info  - Start to collect Reports from remote machines ...");
    my $Err=RunCmds("rm -rf $$Conf{DownLoadFolder}");
	foreach my $PRec (@RemoteList) 
    {
	   ## $G_ErrorCounter += RunCmds("mkdir -p /tmp/$$PRec{Machine}","rm -f /tmp/$$PRec{Machine}/*");
	   my $JustName = $$Conf{ReportFile} =~ /([^\/]+)$/ ? $1 : $$Conf{ReportFile};
	   $Err += RunCmds("mkdir -p $$Conf{DownLoadFolder}/$$PRec{Machine}");
	   $$PRec{ExpCmd}="expect /usr/cti/ServiceKit/copy.tcl $$PRec{Machine}:$$Conf{ReportFile} $$Conf{DownLoadFolder}/$$PRec{Machine}/$JustName";
	   my %TmpRec = ( Logs => ["$$Conf{DownLoadFolder}/$$PRec{Machine}/$JustName",$$PRec{LogFile}] );
	   $$PRec{LogFile} .= ".cp";
	   my @TmpList=ReadFile($$PRec{LogFile});
	   unless ( @TmpList > 4 and grep(/Finish Successfully :/,@TmpList[-5..-1]) ) 
	   {
		    WrLog("Error - during Report build of $$PRec{Machine} adding log files ...");
			$Err++;
			push(@{$TmpRec{Logs}},$$PRec{LogFile});
	   }

	   $ZipComp{$$PRec{Machine}}=\%TmpRec;
	}
	$Err += RunExpect($Conf,@RemoteList);
	$Err += GrapLogs(\%ZipComp,$$Conf{TotalZip});
	## Write to screen ###
	my @TotalLog;
	my $JustName = $$Conf{ReportFile} =~ /([^\/]+)$/ ? $1 : $$Conf{ReportFile};
	foreach my $PRec (@RemoteList)
	{
		my @Content=-s "$$Conf{DownLoadFolder}/$$PRec{Machine}/$JustName" ? 
						ReadFile("$$Conf{DownLoadFolder}/$$PRec{Machine}/$JustName")  :
					    ("Error Retrieving Report of $$PRec{Machine}. see log file $$PRec{LogFile}");	
		push(@TotalLog,"",@Content,"",'-' x 100);
	}
	WrLog(@TotalLog);
	return $Err;
}

sub CheckTotalStatus #\%MainConf,\%MachineRec,\%MachineRec ....
{
	my $Conf=shift;
	my @RemoteList=@_;
	my %ZipComp;
	my $Err=0;
	WrLog("Info  - Check Log status of all machines ...");
	foreach my $PRec (@RemoteList) 
    {
	   my @TmpList=ReadFile($$PRec{LogFile});
	   unless ( @TmpList > 4  and grep(/Finish Successfully :/,@TmpList[-5..-1]) ) 
	   {
		    my @TmpLines = ("Error - Excution on $$PRec{Machine} Finish with Errors:");
			push(@TmpLines,ReadFile($$PRec{LogFile}));
			WrLog(@TmpLines);
			$G_ErrorCounter++;
		    $Err++;
	   } else
	   {
		   WrLog("Info - Excution on $$PRec{Machine} Finished Successfully");
	   }
	}
	return $Err;
}

sub TraceKill
{
	my @ParentPIDs=@_;
	my $PidStr=join(',',@ParentPIDs);
	my @PidList=`ps u --ppid $PidStr`;
	shift(@PidList);
	if ( @PidList ) 
	{
		for (my $i=0; $i < @PidList ; $i++ ) 
		{
			$PidList[$i] =~ /((\S+)\s+){2}/ or delete $PidList[$i], next;
			$PidList[$i] = $2;
		}
		TraceKill(@PidList);
	}
	my @Signals=(3,9);
	foreach my $Sig (@Signals) 
	{
		$PidStr=join(' ',@ParentPIDs);
		@PidList=`ps u --pid $PidStr`;
        shift @PidList;
		if ( @PidList ) 
		{
			@ParentPIDs=();
			foreach $PidStr (@PidList) 
		    {
			    $PidStr =~ /((\S+)\s+){2}/ and push(@ParentPIDs,$2);
		    }
			$PidStr=join(',',@ParentPIDs);
			## WrLog("Debug - Killing $Sig:",@PidList);
			RunCmds("kill -$Sig $PidStr");
		    sleep(1);
		} else
		{
			last;
		}
	}
}

sub RunExpect  #\%Config,\%ExpectRec,\%ExpectRec
{
	my $Conf=shift;
	my @ExpectList=@_;
	my @ProceesList;
	my %ProcessMap;
    my $TmpPIdFile="/tmp/PIDList.txt";
	####  Start Running all commads parallel
	foreach my $Record (@ExpectList) 
	{
		RunCmds("rm -f $$Record{LogFile}");
		$G_OutErr=$$Record{LogFile};
	    my $PId=fork();
	    if ( $PId ) 
	    {   #### Parent .... ###
		   $ProcessMap{$PId}=$Record;
		   push(@ProceesList,$PId);
		   WrLog("Info  - Start Running on $$Record{Machine} ($PId)...");
	    } else
		{
		   $G_Flag="I am the Process That Run: $$Record{ExpCmd}";
		   @G_Log=`$$Record{ExpCmd} 2>&1` ;
		   my $Err=$?;
		   @G_Log or $Err++;
		   push(@G_Log,$Err ? "Error - \"$$Record{ExpCmd}\" - finsihed with exit code $Err" : "Info - Finish with Exit Code $Err" );
		   while ( $? ) 
		   {
			   my $Tmp=`echo`;
		   }
		   WriteFile($$Record{LogFile},@G_Log);
		   exit 0;
	    }
    }
   
   ####   my $Flag=@ProceesList;
   ##### wait all chiled (Remote connection) finish ####
   my $TimeOutFlag=$$Conf{RestartTimeOut} + $$Conf{StartTimeOut} + 15;
   while ( @ProceesList and $TimeOutFlag ) 
   {
	   sleep(1);
	   $TimeOutFlag--;	
	   my $Cmd=sprintf("ps s p %s",join(' ',@ProceesList));
	   exists $G_CLIParams{D} and WrLog("Debug - check Process: \"$Cmd\"");
	   my @Stam=`$Cmd` ;
	   ### Ignore Title ###
	   shift(@Stam);
	   ## WrLog("debug - Line 1 is $Stam[0]");
	   @ProceesList=grep(/(\S+\s+){4}([SRsr])/,@Stam);
	    for (my $i=0; $i< @ProceesList; $i++) 
	    {
			$ProceesList[$i] =~ /(\s*(\d+)){2}/ and $ProceesList[$i]=$2;
	    }
   }
   ########   Kill all Time Out Process !!!!
   if ( @ProceesList ) 
   {
		WriteFile($TmpPIdFile,@ProceesList);
		StopBackground({PIDFile => $TmpPIdFile});
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

$G_ErrorCounter += ReadCLI();
my @Operation=getOperation();
my @DebugMessages=("$0 Input Parameters:");
while ( my ($PName,$PVal ) = each(%G_CLIParams) )
{
     push(@DebugMessages,sprintf("\t-%-20s = $PVal",$PName));
}
WrLog(@DebugMessages,"");
if ( $G_ErrorCounter )
{
    usage();
    EndProg(1);
}

my %Configuration=LoadIniFile($G_CLIParams{Conf});
unless ( exists $Configuration{FileName} ) 
{
    EndProg(1,"Fatal - fail to load configuration file \"$G_CLIParams{Conf}\"");
}

my %MainCnf=ReadConfig(\%Configuration);

### Set List of all components ###

my %ComponentsList=getComponents(\%Configuration,\%MainCnf);

if ( exists $G_CLIParams{Remote} )
{
   my $ScriptName = $0 =~ /\/.+/ ? $0 : "/usr/cti/ServiceKit/$0" ;
   my %CLI=%G_CLIParams;
   delete $CLI{Remote} ;
   $CLI{LogFile}="- ChiledLog.log";
   my @SwitchParams;
   while ( my ($Switch,$SwVal) = each(%CLI) ) 
   {
		push(@SwitchParams,"-$Switch $SwVal");
   }
   my $CmdLine=sprintf("$ScriptName %s",join(' ',@SwitchParams));
   my $ExpFile="/usr/cti/ServiceKit/RunCmds.tcl";
   my @RemoteList;
   my $ProceesList;

   #### Start Remote for each host   ####
   foreach my $Host (split(',',$MainCnf{MachineList}) ) 
   {
	   my %RemoteRec = ( Machine	=> $Host ,
						 ExpCmd		=> "expect $ExpFile -Host $Host -Answer /tmp/a.txt -Cmdline \"$CmdLine\"" ,
						 LogFile	=> "/tmp/$Host.log" );
	   push(@RemoteList,\%RemoteRec);
   }
   RunExpect(\%MainCnf,@RemoteList);
   ## WrLog("","","Debug - !!!!!!","Debug - all Machines finished to Run !!","","");
   $G_ErrorCounter += $Operation[2]->(\%MainCnf,@RemoteList);
} else
{
    $G_ErrorCounter += $Operation[1]->(\%ComponentsList,\%MainCnf,\%Configuration);
}

my $ErrMessage= $G_ErrorCounter ? "Finish with ERRORS see Log File $G_CLIParams{LogFile}" :
		"Finish Successfully :-)";
EndProg($G_ErrorCounter,$ErrMessage);