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
					TimeOut	=> 180 );
my @G_FileHandle=();

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
			$OldTag[0]->appendText($Val);
			exists $G_CLIParams{D} and WrLog("Debug - New Node is ",$OldTag[0]->toString);
		}
		$Result or last;
	}
	return $Result;
}



sub RunCompas
{
	my @InputVar=@_;
	my $TmpFile="/tmp/Input.txt";
	my $Cmd="su - compas -c \"io < $TmpFile\"" ;
	if ( WriteFile($TmpFile,@InputVar) )
	{
		WrLog("Error - Fail to write Comnad file to compas ...");
		$G_ErrorCounter++;
		return ;
	}
	my @Result=`$Cmd`;
	exists $G_CLIParams{D} and RunCmds($Cmd);
	return @Result;
}

sub RemoteCompas  ### URL,INPUT
{
	my $Url=shift;
	my @InputVar=@_;
	my $HostStr = $Url =~ /\/\/(.+?:\d+)/ ? $1 : "127.0.0.1:51445";
	my $Headers=HTTP::Headers->new( "Cache-Control"	=> "no-cache",
									"Host"			=> $HostStr ,
									"Content-type"	=> "application/x-www-form-urlencoded; charset=UTF-8" ) ; 
	my $See=LWP::UserAgent->new();
	exists $G_CLIParams{D} and WrLog("Debug - credentials($HostStr,CompasRealm,SPM_APP_USER,J5_W18fk):", join("",@InputVar),"==========");
	$See->head($Url,$Headers);
	$See->credentials($HostStr,"CompasRealm","SPM_APP_USER" => "J5_W18fk");
	my $Res=$See->post($Url,Content => { "provRequest" => join("",@InputVar) });
	exists $G_CLIParams{D} and WrLog("Debug - Request have been send ...");
	ref $Res or WrLog("Error - Compas Have Not Return Responce ..."),$G_ErrorCounter++;
	unless ( $Res->is_success )
	{
        WrLog(sprintf("Error - Compas ($HostStr) Return %s , %s :",$Res->base,$Res->status_line));
		$G_ErrorCounter++;
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
						"Provisioning/Request/Header/EntityName=" . ( $_[3] or "Default" ) ] ,
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
								 "XDSVRequests/XDSVRequest/Attributes/Attribute/\@Name=cnsServiceLevelID" ] );
	
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
WaitUp("ComPAS");

my $XmlCmd=GetCompasCmd("GetSystem",$G_CLIParams{SysName}) ;   
## my $XmlCmd=GetCompasCmd("GetServiceID") ;   ### T Delete !!!
## WrLog("Debug - After First Line $XmlCmd :",$XmlCmd,"","");

@DebugMessages=RunCompas($XmlCmd);
## @DebugMessages=RemoteCompas("http://10.106.174.23:51445/compas/ProvisionServlet"  ,$XmlCmd);
$DebugMessages[0] =~ s/^.*?(<\?)/$1/ or EndProg(1,"Error - Fail to retreive system info via compas. Compas Responce:",@DebugMessages) ;
my @DomainList;
### WrLog("Debug - ",@DebugMessages,"","============");
$XmlCmd=XML::LibXML->new()->parse_string($DebugMessages[0]);
my $ResStatus=$XmlCmd->find("//Response/Header/ResponseStatus");
$ResStatus =~ /Success/i or EndProg(1,"Error - Fail to Retreive System Info From Compas:",$XmlCmd->find("//Error/Description") );
foreach my $DomainXml ( $XmlCmd->findnodes("//Domain/Name") )
{
	push(@DomainList,$DomainXml->textContent);
}
WrLog(sprintf("Info  - List of Domain in system $G_CLIParams{SysName}: %s",join(',',@DomainList)));
@DomainList or WrLog("Error - No Domain have found at system $G_CLIParams{SysName}:",@DebugMessages);
foreach my $Service ( split(/,/,$G_CLIParams{Services} ) )
{
	@DebugMessages = $XmlCmd->findnodes("//Services/Service[Name=\"$Service\"]");
	unless ( @DebugMessages )
	{
		WrLog("Error - Service \"$Service\" Not Exists at This System - Skip configuration of Default domain for this Service"); 
		$G_ErrorCounter++;
		next;
	}
	foreach my $Domain (@DomainList)
	{
		my $DefServiceLevel=GetCompasCmd("SetDefService",$Service,$Domain,$G_CLIParams{SysName},"Default");
		@DebugMessages=RunCompas($DefServiceLevel->toString());
		unless ( $DebugMessages[0] =~ s/^.+?(<\?)/$1/ )
		{
			WrLog("Error - Fail to Create Default serviceLevel \"$Service\" for domain \"$Domain\". Compas Responce:",@DebugMessages) ;
			$G_ErrorCounter++;
			next;
		}
		$DefServiceLevel=XML::LibXML->new()->parse_string($DebugMessages[0]);
		$ResStatus=$XmlCmd->find("//Response/Header/ResponseStatus");
		$ResStatus =~ /Success/i and WrLog("Info - Update Default $Service for domain $Domain"),next;
		$G_ErrorCounter++;
		WrLog("Error - Fail to Create Default serviceLevel \"$Service\" for domain \"$Domain\":",$DefServiceLevel->find("//Error/Description"),"");
	}
}
my $ErrMessage= $G_ErrorCounter ? "Finish with ERRORS see Log File $G_CLIParams{LogFile}" :
		"Finish Successfully :-)";
EndProg($G_ErrorCounter,$ErrMessage);