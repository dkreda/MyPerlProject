#!/usr/cti/apps/CSPbase/Perl/bin/perl

#####################################################################
#  Note - This script use the CSPBase perl cause it requiers 
#         the Xpath Module ....
#####################################################################

use strict;

use XML::LibXML ;

#########################################################
#  Global variables
#########################################################

my $G_ErrorCounter=0;
my %G_CLIParams=(  LogFile  => "-" );
my $G_Suffix="ServiceKit";

sub usage
{
    print "$0 -Services <Yes,No,....> -Conf <csv File configuration> [-LogFile FileName]\n";
    print "$0 -help\n";
    print "\n\twhere Services = list sperated by comma (,) of the requeired services.\n";
    print "\tand     Conf     = csv file name which contain the resource defnition table";
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
    my $Err = WriteFile($$Rec{FileName},@$Content);
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

sub amIBalancer
{
    my $LocalIP=`hostname -i`;
    my $DNSServer= -e "/etc/named.conf" ? `grep forwarders /etc/named.conf` : `grep nameserve /etc/resolv.conf`;
    
    chomp($LocalIP,$DNSServer);
    return $DNSServer =~ m/[^0-9]$LocalIP[^0-9]/ ;
}

sub setFileName # operand,filename
###############################################################################
#
# Input:	$Operand (enable or disable)
#		$FileName File name 
#
# Return:	0 - O.K , !0 if error
#
# Description:  Disable or enable file ( rename the file with suffix ServiceKit)
#
###############################################################################
{
    my $Operand=shift;
    my $AppFile=shift;
    my ($SrcFile,$DesFile,@CmdList);
    
    if ( $Operand eq "enable" )
    {
    	$SrcFile="$AppFile.$G_Suffix";
    	$DesFile="$AppFile";
    } else
    {
    	$DesFile="$AppFile.$G_Suffix";
    	$SrcFile="$AppFile";
    }
    @CmdList=();
    unless ( -e $DesFile )
    {
	unless ( -e $SrcFile )
	{
	    if (  $Operand eq "enable" )
	    {
	    	WrLog("Error\tFile $SrcFile is missing.");
	    	return 1;
	    }
	}
	push(@CmdList,"mv $SrcFile $DesFile");
    } else
    {
	WrLog("Info\tFile $DesFile alreaday exists. ignore request.");
	if ( -e $SrcFile )
	{
	    WrLog("Info\tBoth files exists $SrcFile, and $DesFile. delete $SrcFile");
	    push(@CmdList,"rm -rf $SrcFile");
	}
    }
    return RunCmds(@CmdList);
}

sub setApp # operand,filename
###############################################################################
#
# Input:	$Operand (enable or disable)
#		$FileName Application File name ( should be ApplicationName.xml )
#
# Return:	0 - O.K , !0 if error
#
# Description:  Disable or enable babysitter application file ( rename the file )
#
###############################################################################
{
    my $Operand=shift;
    my $AppFile=shift;
    my $BaseFolder="/usr/cti/conf/babysitter";
    $AppFile =~ m/$BaseFolder/ or $AppFile = "$BaseFolder/$AppFile";
    my $Err=setFileName($Operand,$AppFile);
    if ( $Err )
    {
    	$AppFile =~ s/^.*\/// ;
    	WrLog("Error - Fail to $Operand $AppFile");
    }
    return $Err;
}    

sub DelFarms #@Farms
###############################################################################
#
# Input:	@Farms or (Farm[,farm,farm ....])
#
# Return:       0 - O.K    !0 Error.
#
# Description: Delete farms from balancer.
#
###############################################################################
{
    my $BalancerFile="/usr/cti/conf/balancer/balancer.conf";
    my @Farms=@_;
    my ($FarmSec,$Domain,$Line,$State,@ExistList);
    my $Err=$G_ErrorCounter;
    my @Content=ReadFile($BalancerFile);
    $Err == $G_ErrorCounter or return 1;
    my @NewContent=();
    $State="Read";
    foreach $Line (@Content)
    {
    	if ( $Line =~ /\[farm=(.+)\]/ )
    	{
    	   $State="Read";
    	   $FarmSec=$1;
    	   ### Check just the name part ( without domain )
    	   $Domain = $FarmSec =~ s/\.(.+)// ? $1 : "" ;
    	   @ExistList = grep ( /$FarmSec/i , @Farms);
    	   ### Check with domain
    	   foreach my $FarmTest (@ExistList)
    	   {
    	   	"$FarmTest." =~ m/$FarmSec\.$Domain/i or next ;
    	   	$State="Delete";
    	   	WrLog("Info - remove farm \"$FarmTest\" from balancer");
    	   	last;
    	   }
    	 }
    	 $State eq "Delete" and next;
    	 push (@NewContent,$Line);
    }
    return WriteFile($BalancerFile,@NewContent);
}

sub UpdateProfile
###############################################################################
#
# Input:	@List
#
# Return:
#
# Description:
#
###############################################################################
{
    my $FileName=shift ; ## "SessionProfiles.xml";
    my $Err=0;
    my @ResourceList=@_;
    unless ( -e $FileName )
    {
    	WrLog("Error - File $FileName not Exist !. can not change seesion profile defintions");
    	return 1;
    }
    my $XmlDoc= XML::XPath->new(filename => $FileName);
    my ($Xpath,$XValue);
    foreach my $Node (@ResourceList)
    {
    	$Node =~ m/^(.+)=(.*?)$/ ;
    	$Xpath=$1;
    	$XValue=$2;
    	## WrLog("-- Debug Going to update $Xpath ...");
    	## my $Result=$XmlDoc->findvalue($Xpath);
    	## WrLog("-- Debug Exist Value is $Result New Value is $XValue");
    	unless ( $XmlDoc->exists($Xpath) )
    	{
    	     WrLog("Error - Xpath $Xpath Not Exist ! at file $FileName");
    	     $Err++;
    	     next;
    	}
    	$XmlDoc->setNodeText($Xpath,$XValue);
    }
    my @Lines=();
    foreach my $Node ( $XmlDoc->findnodes("/") )
    {
    	push(@Lines,$Node->toString());
    }
    my $PI = XML::XPath::Node::PI->new('xml', 'version="1.0"');
    unshift(@Lines,$PI->toString());
    $Err += WriteFile($FileName,@Lines);
    return $Err;
}

sub UpdateApps #\%ResurceRec,\@ResList
{
    my $ResRec=shift;
    my $AppList=shift;
    my $Err=$G_ErrorCounter;
    WrLog("Info - Start Enable/Disable Application at babysitter");
    foreach my $Iter (@$AppList)
    {
    	my $Message=sprintf("Info - Application %-20s %s",$Iter,$$ResRec{$Iter});
    	WrLog($Message);
    	if ( setApp(lc($$ResRec{$Iter}),$Iter) )
    	{
    	    WrLog("Error - Fail to update application $Iter.");
    	    $G_ErrorCounter++;
    	}
    }
    return $G_ErrorCounter-$Err;
}

sub UpdateFiles #\%ResurceRec,\@ResList
{
    my $ResRec=shift;
    my $AppList=shift;
    my $Err=$G_ErrorCounter;
    WrLog("Info - Start Enable/Disable Files");
    foreach my $Iter (@$AppList)
    {
    	my $Message=sprintf("Info - File %-20s %s",$Iter,$$ResRec{$Iter});
    	WrLog($Message);
    	if ( setFileName(lc($$ResRec{$Iter}),$Iter) )
    	{
    	    WrLog("Error - Fail to update File $Iter.");
    	    $G_ErrorCounter++;
    	}
    }
    return $G_ErrorCounter-$Err;
}

sub UpdateFarms
{
    my $ResRec=shift;
    my $FarmList=shift;
    amIBalancer() or return 0;
    my @DelList=();
    my $Err=$G_ErrorCounter;
    
    WrLog("Info - Start Update Balancer farms ...");
    	
    foreach my $FarmName (@$FarmList)
    {
    	$$ResRec{$FarmName} =~ /disable/i and push(@DelList,$FarmName);
    	WrLog(sprintf("Info - Farm        %-20s %s",$FarmName,$$ResRec{$FarmName}));
    }
    $#DelList >= 0 and $G_ErrorCounter += DelFarms(@DelList);
    return $G_ErrorCounter-$Err;
}

sub UpdateSPName #\%ResurceRec,\@ResList
{
    my $ResRec=shift;
    my $ResList=shift;
    my $FileName="/usr/cti/conf/mmsgw/config/SessionProfiles.xml";
    my @StatusList=();
    my $Status;
    ## WrLog(" --- Debug Check Pointers: HasTabale $ResRec , Array $ResList");
    foreach my $Iter (@$ResList)
    {
    	$Status= $$ResRec{$Iter} =~ m/enable/i ? "true" : "false";
    	WrLog(sprintf("Info - SeesionProfile %-40s -> $$ResRec{$Iter} ($Status)",$Iter));
    	push(@StatusList,"//SessionProfiles/SessionProfile\[\@name=\"$Iter\"\]/\@enabled=$Status");
    }
    return UpdateProfile($FileName,@StatusList);
}

sub CheckService
{
    my $ResRec=shift;
    my $ResList=shift;
    WrLog("Info - Check Services Combination ..." ,
          "     --------------------------------");
    foreach my $ResName ( @$ResList )
    {
    	$$ResRec{$ResName} =~ /enable/i and next;
    	WrLog("Error - Service combination not allowed (Rule Name $ResName)");
    	return 1;
    }
    return 0;
}

sub UpdateConf
{
    ## WrLog("Debug - Not Ready Yet");
    my $ResRec=shift;
    my $ResList=shift;
    my %ParmsFiles;
    my $Err=0;
    foreach my $Param (@$ResList)
    {
    	unless ( $Param =~ /(.+):(.+)/ )
    	{
    	     WrLog("Error - Parameter Definition syntax Error: \"$Param\"",
    	           "      Parametr format should be filename:parameter");
    	     $Err++;
    	     next;
    	}
    	my ($FileName,$ParamName)=($1,$2);
    	unless ( defined $ParmsFiles{$FileName} )
    	{
    	     my %IniRec=LoadIniFile($FileName);
    	     $ParmsFiles{$FileName}=\%IniRec;
    	}
    	SetSection($ParmsFiles{$FileName},"Octopus.Parameters.Values",($ParamName => $$ResRec{$Param}));
    	WrLog("Info - Update $ParamName  ->  $$ResRec{$Param}");
    	#while ( my ($RecKey,$RecVal) = each (%$ResRec) )
    	#{
    	#	WrLog("Debug - ($RecKey) => $RecVal");
    	#}
    }
    WrLog("Debug - Start writing parameter into files");
    foreach my $Pointer ( values(%ParmsFiles) )
    {
    	$Err += UpDateIniFile($Pointer);
    }
    return $Err;
}

sub UpdateSPType
{
    ##WrLog("Info - Update Session profile Type is not ready Yet ! ...");
    my $ResRec=shift;
    my $ResList=shift;
    my $FileName="/usr/cti/conf/mmsgw/config/MMSConfiguration.xml";
    my @StatusList=();
    my $Status;
    ## WrLog(" --- Debug Check Pointers: HasTabale $ResRec , Array $ResList");
    foreach my $Iter (@$ResList)
    {
    	$Status= $$ResRec{$Iter} =~ m/enable/i ? "true" : "false";
    	WrLog(sprintf("Info - Activated Service %-40s -> $$ResRec{$Iter} ($Status)",$Iter));
    	push(@StatusList,"//MMS_CONFIGURATION/ActivatedServices/ActivatedService\[\@name=\"$Iter\"\]/\@enabled=$Status");
    }
    return UpdateProfile($FileName,@StatusList);
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

sub SetResource # $FileName,$Services
{
    my $FileName=shift;
    my $ServiceStr=shift;
    my $Err=$G_ErrorCounter;
    ##  $Err += RunCmds("dos2unix $FileName $FileName");
    unless ( $Err == $G_ErrorCounter )
    {
    	WrLog("Error - Fail to read file $FileName. Skip Resource Configuration");
    	return 1;
    }
    my @TableContent=ReadFile($FileName);
    my (@FarmList,@AppList,@SessionNames,@SessionTypes,@ServiceName,@Field,%ResourceStatus,@FilesResource,@CheckList,@ParamsList);
    my $FieldSize=3;
    my %NotOp=( enable	=>	"disable" ,
   	        disable	=>	"enable" );
    my %Type=( Application => [\@AppList,\&UpdateApps] ,
    	       farm	   => [\@FarmList,\&UpdateFarms] ,
    	       "SP Name"   => [\@SessionNames,\&UpdateSPName] ,
    	       "SP Type"   => [\@SessionTypes,\&UpdateSPType] ,
    	       "File"	   => [\@FilesResource,\&UpdateFiles] ,
    	       "Check"	   => [\@CheckList,\&CheckService] ,
    	       "Param"	   => [\@ParamsList,\&UpdateConf] );
    unless ($Err == $G_ErrorCounter)
    {
    	WrLog("Error - Fail to read csv file \"$FileName\". skip Resource Configuration.");
    	return 1;
    }
    while ( $#TableContent >= 0 and $#Field < 0 )
    {
    	@Field=CheckTitle(shift(@TableContent),$ServiceStr);
    	$G_ErrorCounter > $Err and return 1;
    } 
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
    	   while ( $? ) { my $Tmp=`` }
    	}
    }
    
    return $G_ErrorCounter - $Err;
    
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
    foreach ("Services","Conf")
    {
    	unless ( defined $G_CLIParams{$_} )
    	{
    	     WrLog("Error - missing command line parameter $_");
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
SetResource($G_CLIParams{Conf},$G_CLIParams{Services});
my $Message= $G_ErrorCounter ? "Fatal - Error during Service configuration" :
		" --- Finish succesfuly ---";
EndProg($G_ErrorCounter,$Message);