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
use LWP::UserAgent;
use HTTP::Request ;

#########################################################
#  Global variables
#########################################################

my $G_ErrorCounter=0;
my %G_CLIParams=(  LogFile  => "-" ,
					TimeOut	=> 180 ,
					Domains	=> "All" );
my @G_FileHandle=();
my %G_ComPAS;

sub usage
{
    print "$0 -SysName PVVM System Name -Services List of services to create Default serviceLevel [-LogFile FileName]\n";
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

sub CheckProcessUp ## @List of Process
{
	my @ProcessList=@_;
	my @Status=`MamCMD d`;
	my $DownFlag= $? ? 1 : 0; 
	$G_ErrorCounter += $DownFlag;
	chomp @Status;
	my $RegStr=join('|',@ProcessList);
	my @ChkList=grep(/$RegStr/,@Status) ;
	if ( @ProcessList > @ChkList )
	{  ### Not All process Exists at This Machine ...
		my %DubleChk;
		foreach my $Line ( @Status )
		{
			$Line =~ /(\S+)\s+/ or next ;
			$DubleChk{$1}=1;
		}
		foreach my $ProcName (@ProcessList)
		{
			exists $DubleChk{$ProcName} and next;
			WrLog("Error - The Process $ProcName is not Monitor by Babysiter on this Machine.");
			$G_ErrorCounter++;
		}
		return 0 ;
	}
	foreach my $AppName ( @ChkList )
	{
		$AppName =~ /(\S+)\s+Up/i and next;
		$DownFlag++;
		WrLog("Info - $1 is Still Down");
	}
	WrLog("Info - $DownFlag Applications are Down");
	return $DownFlag ? 0 : 1;
}

sub WaitUp # @List of Process
{
	my @ProcessList=@_;
	my $Res=13;
	CheckProcessUp(@ProcessList) and return;
	for ( my $Count= $G_ErrorCounter ? 0 : $Res ; $Count ; $Count-- )
	{
		sleep( ($G_CLIParams{TimeOut} / $Res) % $G_CLIParams{TimeOut} );
		CheckProcessUp(@ProcessList) and return;
	}
	sleep( $G_CLIParams{TimeOut} % $Res);
	CheckProcessUp(@ProcessList) and return;
	EndProg(1,"Error - Not all Required Process are Up");
}

sub BuildElement #$XmlNode,$Xpath
{
	my $XmlNode=shift;
	my $Xpath=shift or return $XmlNode;
	exists $G_CLIParams{D} and WrLog("Debug - BuildElement: \"$Xpath\" -> $XmlNode");
	if ( ref $XmlNode )
	{
		my @NodeList ;
		my $NewPath;
		while ( ! @NodeList )
		{
			@NodeList=$XmlNode->findnodes("/$Xpath") and last ;
			exists $G_CLIParams{D} and WrLog(sprintf("Debug - list of Match Xpath is %d",$#NodeList));
			## @NodeList or ( $Xpath =~ s/\/?([^\/]+)$// and $NewPath= $NewPath ? "$1/$NewPath" : $1 ) ;
			$Xpath =~ s/\/?([^\/]+)$// and $NewPath= $NewPath ? "$1/$NewPath" : $1 ;
			exists $G_CLIParams{D} and WrLog("Debug - Loop ... Xpath=$Xpath NewPath=$NewPath  ... @NodeList",$XmlNode->nodePath());
		}
		exists $G_CLIParams{D} and WrLog("Debug - Finish to Search Element ... Xpath=$Xpath NewPath=$NewPath");
		unless ( @NodeList )
		{
			exists $G_CLIParams{D} and WrLog("Debug - In Error ....");
			WrLog("Error - Xpath Root ($Xpath) do not Match any Node at XmlNode:",$XmlNode->toString);
			$G_ErrorCounter++;
			return ;
		}
		$NewPath or return $XmlNode;
		my $TmpNode=BuildElement("",$NewPath);
		$TmpNode or return ;
		exists $G_CLIParams{D} and WrLog("Debug - Insert -",$TmpNode->toString(),"\t\tTO ....",$NodeList[-1]->toString());
		$NodeList[-1]->appendChild($TmpNode);
	} else
	{   ### XmlNode is Not an object (empty)
		$Xpath =~ s/\[.+?\]//;
		$XmlNode=XML::LibXML->new()->parse_string( $Xpath =~ /([^\/]+)\// ? "<$1/>" : "<$Xpath/>" );
		exists $G_CLIParams{D} and WrLog("Debug - New Object calling requrse: \"$Xpath\" -> $XmlNode");
		$XmlNode=BuildElement($XmlNode,$Xpath);
		$XmlNode=$XmlNode->documentElement();
	}
	exists $G_CLIParams{D} and WrLog("Debug About to Return $XmlNode");
	return $XmlNode;
}

sub BuildXmlCommand  ## @ListofXpaths
{
	my @Lines=@_;
	my $Result;
	exists $G_CLIParams{D} and WrLog("Debug - Start build Compas Command for:",@Lines);
	foreach my $Line (@Lines)
	{
		$Line =~ /(.+)=(.+)/ or next;
		my $Val=$2;
		my $Xpath=$1;
		exists $G_CLIParams{D} and WrLog("Debug - in BuildCommand Loop ...");
		if ( $Xpath =~ s/\/\@(.+)// )
		{
			my $AttrName=$1;
			$Result=BuildElement($Result,$Xpath);
			exists $G_CLIParams{D} and WrLog("Debug ----  Result is $Result .... Xpath is $Xpath",$Result->toString());
			my @TmpNode=$Result->findnodes("/$Xpath");
			exists $G_CLIParams{D} and WrLog("Debug --",@TmpNode);
			$TmpNode[0]->setAttribute($AttrName,$Val);
		} else
		{
			exists $G_CLIParams{D} and WrLog("Debug - Calling BuildElement($Result,$Xpath) ...");
			$Result=BuildElement($Result,$Xpath);
			exists $G_CLIParams{D} and WrLog("Debug - Result After BuildElenemnt Recursive :",$Result->toString,"-----> $Xpath");
			my @OldTag=$Result->findnodes("/$Xpath");
			$Val eq "<>" or $OldTag[0]->appendText($Val);
			exists $G_CLIParams{D} and WrLog("Debug - New Node is ",$OldTag[0]->toString);
		}
		$Result or last;
	}
	return $Result;
}



sub LocalCompas
{
	my @InputVar=@_;
	my $TmpFile="/tmp/Input.txt";
	my $Cmd="su - compas -c \"io < $G_ComPAS{TmpFile}\"" ;
	if ( WriteFile($G_ComPAS{TmpFile},@InputVar) )
	{
		WrLog("Error - Fail to write Comnad file to compas ...");
		$G_ErrorCounter++;
		return ;
	}
	my @Result=`$Cmd`;
	exists $G_CLIParams{D} and RunCmds($Cmd);
	$Result[-1] =~ /HST>\s*:\s*$/ and pop(@Result);
	### $Result[0] =~ s/^.*?(<\?)/$1/ ;
	return @Result;
}

sub ExecCompas
{
	my $XmlCmd=GetCompasCmd(@_);
	my $Err=$G_ErrorCounter;
	my @Result=$G_ComPAS{Run}->($XmlCmd);
	chomp @Result;
	my $ResStr=join("",@Result);
	## WrLog("Debug - Before Fix ->",$ResStr);
	$ResStr =~ s/^.*?(<\?)/$1/ ;
	## $ResStr =~ s/[^>]+$// ;
	## WrLog("Debug - After Fix ->","\"$ResStr\"");
	my $XmlRes=  $G_ErrorCounter > $Err ?  undef : XML::LibXML->new()->parse_string($ResStr) ;
	unless ( ref $XmlRes )
	{
		WrLog("Error - Failed to exceute Compas command :","\t" . $XmlRes ,"\t\tCompas Return Responce: $ResStr","");
		$G_ErrorCounter++;
		return ;
	}
	$ResStr=$XmlRes->find("//Response/Header/ResponseStatus");
	unless ( $ResStr =~ /Success/i )
	{
		$ResStr=$XmlRes->find("//Error/Description");
		WrLog("Error - Last Compas Command Return Error: $ResStr","\t- Original Request:",$XmlCmd);
		$G_ErrorCounter++;
		return ;
	}
	return $XmlRes;
}

sub RemoteCompas  ### URL,INPUT
{
	## my $Url=shift;
	my @InputVar=@_;
	my $HostStr = $G_ComPAS{Url} =~ /\/\/(.+?:\d+)/ ? $1 : "127.0.0.1:51445";
	my $Headers=HTTP::Headers->new( "Cache-Control"	=> "no-cache",
									"Host"			=> $HostStr ,
									"Content-type"	=> "application/x-www-form-urlencoded; charset=UTF-8" ) ; 
	my $See=LWP::UserAgent->new();
	exists $G_CLIParams{D} and WrLog("Debug - credentials($HostStr,CompasRealm,SPM_APP_USER,J5_W18fk):", join("",@InputVar),"==========");
	$See->head($G_ComPAS{Url},$Headers);
	$See->credentials($HostStr,"CompasRealm","SPM_APP_USER" => "J5_W18fk");
	my $Res=$See->post($G_ComPAS{Url},Content => { "provRequest" => join("",@InputVar) });
	exists $G_CLIParams{D} and WrLog("Debug - Request have been send ...");
	ref $Res or WrLog("Error - Compas Have Not Return Responce ..."),$G_ErrorCounter++;
	unless ( $Res->is_success )
	{
        WrLog(sprintf("Error - Compas ($HostStr) Return %s , %s :",$Res->base,$Res->status_line));
		$G_ErrorCounter++;
		## return ;
    }
	exists $G_CLIParams{D} and WrLog("Debug - Compas Responce:",$Res->decoded_content);
	my @Result=$Res->decoded_content;
	return @Result;
}

sub GetCompasCmd #$Type,@Parametters
{
	my $CmdName=shift;
	my %SPMCmd=( GetSystem	=> ["","Provisioning/Request/Header/Command=Retrieve",
						"Provisioning/Request/Header/EntityIdentifiers/Identifier/\@Type=SystemName" ,
						"Provisioning/Request/Header/EntityIdentifiers/Identifier/\@Value=$_[0]" ,  ### The System Name
						"Provisioning/Request/Header/EntityName=ConfigurationMap"] ,
				 SetDefService => ["","Provisioning/Request/Header/Command=CreateOrModify" , 
						"Provisioning/Request/Header/EntityIdentifiers/Identifier/\@Type=DomainName" ,
						"Provisioning/Request/Header/EntityIdentifiers/Identifier/\@Value=$_[1]" ,
						"Provisioning/Request/Header/EntityIdentifiers/Identifier[2]/\@Type=SystemName" ,
						"Provisioning/Request/Header/EntityIdentifiers/Identifier[2]/\@Value=$_[2]",
						"Provisioning/Request/Header/EntityIdentifiers/Identifier[3]/\@Type=ServiceName" ,
						"Provisioning/Request/Header/EntityIdentifiers/Identifier[3]/\@Value=$_[0]" ,
						 "Provisioning/Request/Header/EntityIdentifiers/Identifier[4]/\@Type=ServiceLevelName" ,
						"Provisioning/Request/Header/EntityIdentifiers/Identifier[4]/\@Value=" . ( $_[3] or "Default" ) ,
						"Provisioning/Request/Header/EntityName=ServiceLevel"] ,
				SetDefDomain => ["","Provisioning/Request/Header/Command=Modify" , 
						"Provisioning/Request/Header/EntityIdentifiers/Identifier/\@Type=DomainName" ,
						"Provisioning/Request/Header/EntityIdentifiers/Identifier/\@Value=$_[1]" ,
						"Provisioning/Request/Header/EntityIdentifiers/Identifier[2]/\@Type=SystemName" ,
						"Provisioning/Request/Header/EntityIdentifiers/Identifier[2]/\@Value=$_[2]",
						"Provisioning/Request/Header/EntityIdentifiers/Identifier[3]/\@Type=ServiceName" ,
						"Provisioning/Request/Header/EntityIdentifiers/Identifier[3]/\@Value=$_[0]" ,
						"Provisioning/Request/Header/EntityName=DomainDefaults" ,
						"Provisioning/Request/Data/DomainDefaults=<>" ] ,
				GetServiceID => ["_executeXdsv=","XDSVRequests/XDSVRequest/\@BypassResolver=true" ,
								 "XDSVRequests/XDSVRequest/\@Command=retrieve" ,
								 "XDSVRequests/XDSVRequest/\@EntityName=SL",
								 "XDSVRequests/XDSVRequest/\@ExecutionPhase=1" ,
								 "XDSVRequests/XDSVRequest/\@ID=1" ,
								 "XDSVRequests/XDSVRequest/\@Host=Profile1" ,
								 "XDSVRequests/XDSVRequest/Scope/\@Key=CnsDomainId" ,
								 "XDSVRequests/XDSVRequest/Scope/\@Type=DOMAIN" ,
								 "XDSVRequests/XDSVRequest/Scope/Value=0" ,
								 "XDSVRequests/XDSVRequest/Scope/Scope/\@Key=CnsServiceName" ,
								 "XDSVRequests/XDSVRequest/Scope/Scope/\@Type=SERVICE" ,
								 "XDSVRequests/XDSVRequest/Scope/Scope/Value=EMS" ,
								 "XDSVRequests/XDSVRequest/Filter/Term/\@Condition=equal" ,
								 "XDSVRequests/XDSVRequest/Filter/Term/\@Name=cnsServiceLevelName" ,
								 "XDSVRequests/XDSVRequest/Filter/Term/Value=" . ($_[0] or "Default" ),
								 "XDSVRequests/XDSVRequest/Attributes/Attribute/\@Name=cnsServiceLevelID" ] ,
				GetSysDef	=> ["","Provisioning/Request/Header/Command=Retrieve",
								"Provisioning/Request/Header/EntityIdentifiers/Identifier/\@Type=ServiceName" ,
								"Provisioning/Request/Header/EntityIdentifiers/Identifier/\@Value=$_[1]" , #### Service Name (Notification / EMS etc ....
								"Provisioning/Request/Header/EntityIdentifiers/Identifier[2]/\@Type=SystemName" ,
								"Provisioning/Request/Header/EntityIdentifiers/Identifier[2]/\@Value=$_[0]" , ## System Name
								"Provisioning/Request/Header/EntityName=SystemDefaults"],
				SetSysDef	=> ["","Provisioning/Request/Header/Command=Modify",
								"Provisioning/Request/Header/EntityIdentifiers/Identifier/\@Type=SystemName" ,
								"Provisioning/Request/Header/EntityIdentifiers/Identifier/\@Value=" . shift , ## System Name
								"Provisioning/Request/Header/EntityIdentifiers/Identifier[2]/\@Type=ServiceName" ,
								"Provisioning/Request/Header/EntityIdentifiers/Identifier[2]/\@Value=" . shift , #### Service Name (Notification / EMS etc ....
								"Provisioning/Request/Header/EntityName=SystemDefaults",@_]);
	
	unless ( exists $SPMCmd{$CmdName} )
	{
		WrLog("Error - The Compas command \"$CmdName\" is not known - use one of :",keys(%SPMCmd));
		$G_ErrorCounter++;
		return;
	}
	my @StrList=@{$SPMCmd{$CmdName}};
	my $Prefix=shift (@StrList);
	my $XmlObj=BuildXmlCommand( @StrList );
	$XmlObj = $XmlObj ? $Prefix . $XmlObj->toString() : ""; 
	return $XmlObj ;
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
if ( exists $G_CLIParams{Remote} )
{
	$G_ComPAS{Run}=\&RemoteCompas;
	$G_ComPAS{Url}=  $G_CLIParams{Remote};
	$G_ComPAS{Mode}="Remote"
} else
{
	$G_ComPAS{Run}=\&LocalCompas;
	$G_ComPAS{TmpFile}=  "/tmp/Input.txt";
	$G_ComPAS{Mode}="Local";
	WaitUp("ComPAS");
}
WrLog("Info - Compas Client Mode - $G_ComPAS{Mode}");
my $XmlCmd=ExecCompas("GetSystem",$G_CLIParams{SysName}) ;   
ref $XmlCmd or EndProg(1,"Error - Fail to Retreive System Info From Compas");
my @DomainList;
foreach my $DomainXml ( $XmlCmd->findnodes("//Domain/Name") )
{
	push(@DomainList,$DomainXml->textContent);
}
WrLog(sprintf("Info  - List of Domain in system $G_CLIParams{SysName}: %s",join(',',@DomainList)));
@DomainList or WrLog("Error - No Domain have found at system $G_CLIParams{SysName}:",@DebugMessages);

### Read System Defaults
$XmlCmd=ExecCompas("GetSysDef",$G_CLIParams{SysName},"Notification") ;
if ( ref $XmlCmd )
{
	###  Start Connfiguring Notification Service
	my @NotifMethods;
	foreach my $NotifNode ( $XmlCmd->findnodes("//Data/SystemDefaults/AllowedNotifMethods/Value") )
	{
		push(@NotifMethods,$NotifNode->textContent );
	}
	WrLog("Debug - Notif Methoss: ",@NotifMethods,"","");
	####    Add Notify Type ....
	my (%Methods,%Dest);
	unless ( grep(/VVM:MainPhone/,@NotifMethods) )
	{
		push(@NotifMethods,"VVM:MainPhone");
		my @TmpList;
		foreach my $Stam ( @NotifMethods )
		{
			push(@TmpList,"Provisioning/Request/Data/SystemDefaults/AllowedNotifMethods/Value=$Stam");
			$Stam =~ /VVM/ and next;
			my @List=split(/:/,$Stam);
			$Methods{$List[0]}=1;
			$Dest{$List[1]}=1;
		}
	
		$XmlCmd=ExecCompas("SetSysDef",$G_CLIParams{SysName},"Notification",@TmpList) ;
		ref $XmlCmd or EndProg(1,"Error - Fail to Add VVM:MainPhone Notif method");
	}
	#### Start Parse the NotifRules   ###
	
	
	
	foreach my $NotifNode ( $XmlCmd->findnodes("//NotifRules/NotifRule") )
	{
		WrLog("Debug - Notif ?:",$NotifNode->toString);
	}
	###  VVM Notif Rules Definitions
	my @NotifList = ( ["NotifAction=Deactivate",
					   "NotifRuleEnabled=true" ,
					   ### "NotifMethod=VVM" ,  ### All Non VVM Users
					   ###  "NotifDestination=MainPhone" ,  ### All NonVVM users
					   "NotifClientID/Value=!VVM_App_User" ,
					   "NotifRuleOn=false" ,
					   "NotifTriggers/Value=VVMSubModifyProfile" ,
					   "NotifRuleSelfProvEnabled=false" , 
					   "NotifOriginalTriggers/Value=Deposit" ] ,
					   ["NotifAction=ActivateEvery",
					   "NotifRuleEnabled=true" ,
					   "NotifMethod=VVM" ,
					   "NotifDestination=MainPhone" ,
					   "NotifClientID/Value=!VVM_App_User" ,
					   "NotifClientID/Value=!MBMON" ,
					   "NotifRuleOn=false" ,
					   "NotifTriggers/Value=Logout" ,
					   "NotifRuleSelfProvEnabled=false" ] ,
					  ["NotifAction=ActivateEvery" ,
					   "NotifRuleEnabled=true" ,
					   "NotifMethod=VVM" ,
					   "NotifDestination=MainPhone" ,
					   "NotifClientID/Value=!VVM_App_User" ,
					   "NotifClientID/Value=!NDS_App_User" ,
					   "NotifRuleOn=false" ,
					   "NotifTriggers/Value=SubCreate" ,
					   "NotifTriggers/Value=VVMSubDelete" ,
					   "NotifTriggers/Value=VVMSubModifyProfile" ,
					   "NotifRuleSelfProvEnabled=false" ] ,
					  ["NotifAction=ActivateEvery",
					   "NotifRuleEnabled=true" ,
					   "NotifMethod=VVM" ,
					   "NotifDestination=MainPhone" ,
					   "NotifClientID/Value=!VVM_App_User" ,
					   "NotifRuleOn=false" ,
					   "NotifTriggers/Value=VVMSubModifyGreeting" ,
					   "NotifRuleSelfProvEnabled=false" ]) ;
					   
	### UpDate NotifRule1 Destination Methods
	
	foreach my $MVal ( keys(%Methods) )
	{
		push(@{$NotifList[0]},"NotifMethod=$MVal");
	}
	foreach my $MVal ( keys(%Dest) )
	{
		push(@{$NotifList[0]},"NotifDestination=$MVal");
	}
    ### Start Parse / Check the Notif Rules at system					   
	foreach  my $Rule ( @NotifList )
	{
		my $CondStr=join(" and ",@$Rule);
		$CondStr =~ s/=(\S+)/="$1"/g ;
		WrLog("Debug  - Condition String: $CondStr");
		my @Flag = $XmlCmd->findnodes("//NotifRules/NotifRule[$CondStr]");
		foreach my $FF (@Flag)
		{
			WrLog("Debug -  Find Match Rul ID :",$FF->find(".//Id"));
		}
		unless ( @Flag )
		{
			WrLog("Info - Notif Rule Not exists add New NotifRule ...");
			my @NotifDef;
			my %Counter;
			foreach my $Line ( @$Rule )
			{
				$Line =~ /(\S+?)=/  ;
				my $CKey=$1;
				if ( exists $Counter{$CKey} )
				{
					$Counter{$CKey}++
				} else 
				{
					( grep(/$CKey=/,@$Rule ) > 1 ) and $Counter{$CKey}=1;
				}
				exists $Counter{$CKey} and $Line =~ s/(\S+?)=/$1\[$Counter{$CKey}\]=/ ;
				push(@NotifDef,"Data/SystemDefaults/NotifRules/$Line");
			}
			WrLog("Debug  - Send Build Command : ",@NotifDef);
			$XmlCmd=ExecCompas("SetSysDef",$G_CLIParams{SysName},"Notification",@NotifDef);
		}
	}
}

my @VVMDomains = ($G_CLIParams{Domains} =~ /All/i ) ? @DomainList : split(/,/,$G_CLIParams{Domains}) ;



EndProg(0,"Tessssssssssssssssssssssssssssst");




foreach my $Service ( split(/,/,$G_CLIParams{Services} ) )
{
	@DebugMessages = $XmlCmd->findnodes("//Services[Name=\"$Service\"]");
	unless ( @DebugMessages )
	{
		WrLog("Error - Service \"$Service\" Not Exists at This System - Skip configuration of Default domain for this Service"); 
		$G_ErrorCounter++;
		next;
	}
	foreach my $Domain (@DomainList)
	{
		foreach my $SLType ("SetDefService","SetDefDomain")
		{
			my $DefServiceLevel=GetCompasCmd($SLType,$Service,$Domain,$G_CLIParams{SysName},"Default");
			@DebugMessages=RunCompas($DefServiceLevel);
			unless ( $DebugMessages[0] =~ s/^.+?(<\?)/$1/ )
			{
				WrLog("Error - Fail to Create Default serviceLevel \"$Service\" for domain \"$Domain\". Compas Responce:",@DebugMessages) ;
				$G_ErrorCounter++;
				last;
			}
			$DefServiceLevel=XML::LibXML->new()->parse_string($DebugMessages[0]);
			my $ResStatus=$XmlCmd->find("//Response/Header/ResponseStatus");
			$ResStatus =~ /Success/i and WrLog("Info - Update Default $Service for domain $Domain"),next;
			$G_ErrorCounter++;
			WrLog("Error - Fail to Create Default serviceLevel /domain \"$Service\" for domain \"$Domain\":",$DefServiceLevel->find("//Error/Description"),$DefServiceLevel,"");
		}
	}
}
my $ErrMessage= $G_ErrorCounter ? "Finish with ERRORS see Log File $G_CLIParams{LogFile}" :
		"Finish Successfully :-)";
EndProg($G_ErrorCounter,$ErrMessage);