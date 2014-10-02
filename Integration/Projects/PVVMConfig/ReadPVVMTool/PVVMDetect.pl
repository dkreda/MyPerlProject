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

use Net::SSH::Perl;

#########################################################
#  Global variables
#########################################################

my $G_ErrorCounter=0;
my %G_CLIParams=(  LogFile  => "-" ,
				   TimeOut	=> 180 ,
				   Domains	=> "All" ,
				   UnitGroupPath => "/usr/cti/conf/balancer/UnitGroup.xml");
my @G_FileHandle=();
my %G_ComPAS;  #####  Delete

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
		## return ;
    }
	exists $G_CLIParams{D} and WrLog("Debug - Compas Responce:",$Res->decoded_content);
	my @Result=split(/[\n\r]/,$Res->decoded_content);
	chomp @Result;
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


sub getAllIps
###############################################################################
#
# Input:	[$ServerIP],@ListDomain
#		$ServerIP
# Return:       @ListofIps
#
# Description: Retreive List of Ips that match the List of Domains -
#		use nslookup method ...
#
###############################################################################
{
    my $ServerIP=shift;
    my @ListOfDomains=@_;
    my (@Result,%IpList,$IPNumber,$Err,$Domain);
    $ServerIP =~ /^(\d+\.){3}\d+$/ or unshift(@ListOfDomains,$ServerIP),undef $ServerIP;
    
    foreach my $FQDN (@ListOfDomains)
    {
    	$Err=0;
		### WrLog("Debug -----------   Domain: $Domain");
    	while ( $Err == 0 )
    	{
    		my @AnswerList = `nslookup $FQDN $ServerIP 2>&1`;
    		$Err += $?;
    		chomp @AnswerList;
			grep(/can't find/,@AnswerList) and $Err++;
			if ( $Err )
			{
				## WrLog("Debug - First Lookup Failed ... Try FQDN.");
				unless ( $Domain )
				{
					foreach my $Line ( grep(/Server/,@AnswerList) )
					{
						### WrLog("Debug ---- Retreiving domain from \"$Line\"");
						$Line =~ /\.(\S+)/ and $Domain=$1 and last;
					}
				}
				$FQDN .= ".$Domain";
				@AnswerList = `nslookup $FQDN $ServerIP`;
				$Err = $?;
			}
			## WrLog("Debug - ",@AnswerList,"--------");
			$Err and WrLog("Warning - Last nslookup command ($FQDN $ServerIP) return error",@AnswerList,"");
    		$IPNumber=0;
    		foreach my $Line ( @AnswerList )
    		{
    	     		$Line =~ m/Name.+$FQDN/ and $IPNumber=1;
    	     		$IPNumber and $Line =~ m/Address.+\s+(\S+)$/ and $IPNumber=$1;
    		}
    		$IPNumber =~ /(\d+\.){3}/ or last;
    		exists($IpList{$IPNumber}) and last;
    		$IpList{$IPNumber}=1;
    		WrLog("Debug - Add The IP $IPNumber as retreive from \"$FQDN\"");
    	}
    }
    @Result=keys(%IpList);
    return @Result;
}

sub ReadGSL
###############################################################################
#
# Input: $SPMIP
#
# Return:  @\%SysRecords
#
# Description:
#
###############################################################################
{
     my $SPMIP=shift;
     my @Result=();
     my $Err=0;
     my $Iter;
	 my %ParamsMap= ( GSL_GROUP_NAME	=>  "Name" ,
					  GSL_GROUP_ID		=>	"SysID" ,
					  COSHOSTNAME		=>  "NetworkDomain" );
     exists  $G_CLIParams{D} and WrLog("Debug - Parssing SPM $SPMIP");
	 my $SQLReq=sprintf("SELECT %s from GSL_GROUPS",join(',',keys(%ParamsMap))); 
	 ## WrLog("Debuuuuuug ---- SQLReq: $SQLReq");
	 my @SQLRes=RemoteCompas("https://$SPMIP:51449/compas/ProvisionServlet","_executeSQL:JdbcPrimaryGsl=$SQLReq");
	 chomp @SQLRes;
	 ## WrLog("Debuggggg  -----  Sql Result: ",@SQLRes);
	 foreach my $Line (@SQLRes) 
	 {
		my %SysRec;
		foreach my $Field ( split(/,/,$Line) )
		{
			$Field =~ /(\S+)=(.+)/ or next;
			my ($DBName,$DBVal)=($1,$2);
			exists $ParamsMap{$DBName} or WrLog("Error - UnKnown DataBase Field $DBName"),$Err++,next;
			
			$SysRec{$ParamsMap{$DBName}}=$DBVal;
			
		}
		keys(%SysRec) > 0 or next;
		$SysRec{NetworkDomain} =~ s/^[^\.]+\.//;
		push(@Result,\%SysRec);
	 }
	 
	 foreach my $Pointer ( @Result )
	 {
	    if ( exists $G_CLIParams{D} )
		{
			WrLog("Debug - Fields Interpated from Compas:") ;
			while ( my ($DKay,$DVal) = each(%$Pointer) )
			{
				WrLog("-D-\t$DKay : $DVal");
			}
		}
		exists $Pointer->{SysID} or WrLog("Error - Missing System ID Info"),$G_ErrorCounter++,next;
		$SQLReq="select SERVICE_DOMAINS.NAME,SERVICE_DOMAINS.SERVICE_ID from GSL_Groups,GSL_ITEMS,SERVICE_DOMAINS where GSL_Groups.GSL_Group_ID=\'$Pointer->{SysID}\' and GSL_Groups.Default_GSL_SET_ID=GSL_ITEMS.GSL_SET_ID and GSL_ITEMS.SVCDOMAIN_ID=SERVICE_DOMAINS.SVCDOMAIN_ID";
		##WrLog("Debuuuuuug ---- SQLReq: $SQLReq");
	    @SQLRes=RemoteCompas("https://$SPMIP:51449/compas/ProvisionServlet","_executeSQL:JdbcPrimaryGsl=$SQLReq");
		chomp @SQLRes;
	    ##WrLog("Debuggggg  -----  Sql Result: ",@SQLRes);
		foreach my $Line (@SQLRes) 
		{
			## my %TmpRec;
			my ($Domain,$ResName);
			foreach my $Field ( split(/,/,$Line) )
			{
				$Field =~ /(\S+)=(.+)/ or next;
				my ($DBName,$DBVal)=($1,$2);
				if ( $DBName =~ /NAME/ )
				{
					$Domain=$DBVal;
				} else
				{
					$ResName=$DBVal;
				}
			}
			##WrLog("Debug - Atempt to find Service Name to $Domain \"$Line\"");
			$SQLReq="select NAME from SERVICES where SERVICE_ID=\'$ResName\'" ;
			my @ResList=RemoteCompas("https://$SPMIP:51449/compas/ProvisionServlet","_executeSQL:JdbcPrimaryGsl=$SQLReq");
			##rLog("Debuuuug - Send \"$SQLReq\"","\tRecieve: ",@ResList,"");
			foreach my $Field ( split(/,/,$ResList[0]) )
			{
				$Field =~ /(\S+)=(.+)/ or next;
				$Pointer->{$2}=$Domain;
				##WrLog("DDDDDD   Update  $Domain with Service Name ....");
			}
		}
	 }
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

sub ReadBalancer # IP , @knownips
{
	my $IP=shift;
	
	my %BalancerList = ( $IP	=> "First" );
	my $TmpSesion ;  ### =Net::SSH::Perl->new($IP);
	###  $TmpSesion->login("root",q/Adm1Cmv4$/);
	my $FindLocalDNS=q[perl -n -e  '/forwarders/ and /((\d+\.){3}\d+)\D+?((\d+\.){3}\d+)/ and print "$1,$3\n"' /etc/named.conf] ;
	my $FindSyncedDNS=q<if [ -e /usr/cti/conf/balancer/balancer.conf ] ; then perl -n -e '/(ProxyBalancerList|NormalBalancerList)=(.+)/ and push(@Ips,$2); END { printf ("%s\n",join(",",@Ips)); }' /usr/cti/conf/balancer/balancer.conf ; fi> ;
	my $Flag="InProcess";
	
	while ( $Flag )
	{
		$Flag=0;
		while ( my ($BalacerIP , $BalncerStatus) = each ( %BalancerList ) )
		{
			$BalncerStatus =~ /Done/ and next;  # "ConnectTimeout" => 5 , 
			## WrLog("Debug -  Detecting / Analyze $BalacerIP ....");
			my $TmpOut=`ping -c 1 $BalacerIP`;
			chomp $TmpOut;
			$TmpOut =~ /(\d+)\s+received/ and $TmpOut=$1;
			unless ( $TmpOut )
			{
				WrLog("Error - Fail to access to $BalacerIP");
				$G_ErrorCounter++ ;
				delete $BalancerList{$BalacerIP} ;
				next;
			}
			## WrLog("Debug - $TmpOut Packets Retrieves ....");
			eval { $TmpSesion=Net::SSH::Perl->new($BalacerIP, "ConnectTimeout" => "3") } or WrLog("Error - Fail to access to $BalacerIP"),$G_ErrorCounter++ ,next;
			$TmpSesion->login("root",q/Adm1Cmv4$/);
			foreach my $CmdLine ( "$FindLocalDNS","$FindSyncedDNS")
			{
				my @Out=$TmpSesion->cmd($CmdLine);
				chomp @Out;
				$Out[2] and WrLog("Error - Fail to retreive balancer info from $BalacerIP :",
								  "\t-Run:\"$CmdLine\"",
								  "\t-Result StdErr:\"$Out[1]\"",
								  "\t-Result StdOut:\"$Out[0]\""), $G_ErrorCounter++ ,last;
				foreach my $TmpIP ( split(/,/,$Out[0]) )
				{
					exists $BalancerList{$TmpIP} and next ;
					$BalancerList{$TmpIP}="InProcess" ;
					$Flag="InProcess";
				}
			}
			if ( $BalncerStatus =~ /First/ )
			{
				$BalancerList{$BalacerIP}="Done" ;
				my @Out=$TmpSesion->cmd(qq<perl -n -e '/forwarders/ and \$FF= (\$_ =~ /\\D$BalacerIP\\D/ ? "O.K" : "Delete" ); \$FF and print "\$FF\\n"; undef \$FF' /etc/named.conf>);
				$Out[0] =~ /O.K/ or delete $BalancerList{$BalacerIP};
			} else
			{
				$BalancerList{$BalacerIP}="Done" ;
			}
		}
	}
	return keys(%BalancerList);
}

sub ReadSPM # IP,\@%SystemList
{
	my $SpmIP=shift;
	my $SysList=shift;
	my $Err=0;
	my %ParamsMaping= ( SysID	=> { FileName 	=> "/usr/cti/conf/compas/localsettings/parameters.xml" ,
									 Xpath		=> q(//Parameter[@Name="SystemId"]/Value/Item/@Value)  } ,
						TuiEncryptMethod	=> { FileName	=> "/usr/cti/conf/compas/common/parameters.xml" ,
												 Xpath		=> q(//Parameter[@Name="TuiPasswordEncryptionMethod"]/Value/Item/@Value) } ,
						MailEncryptMethod	=> { FileName	=> "/usr/cti/conf/compas/common/parameters.xml" ,
												 Xpath		=> q(//Parameter[@Name="MAPasswordEncyptionFormat"]/Value/Item/@Value) } , 
						InternetEncryptMethod => { FileName => "/usr/cti/conf/compas/common/parameters.xml" ,
												   Xpath	=> q(//Parameter[@Name="InternetPasswordEncryptionMethod"]/Value/Item/@Value) } ,
						DefaultMailDomain	=> { FileName	=> "/usr/cti/conf/compas/common/parameters.xml" ,
												 Xpath		=> q(//Parameter[@Name="MADefaultAddressDomain"]/Value/Item/@Value) } 
						## BalancerList		=> { Cmd		=> q[perl -n -e  '/forwarders/ and /((\d+\.){3}\d+)\D+?((\d+\.){3}\d+)/ and print "$1,$3\n"' /etc/named.conf] }
					  );
	my %XmlObjRec;
	my $TmpRec=$ParamsMaping{SysID};
	my $TmpSesion=Net::SSH::Perl->new($SpmIP);
	$TmpSesion->login("root",q/Adm1Cmv4$/);
	my @OutPut=$TmpSesion->cmd("cat $TmpRec->{FileName}");
	$OutPut[2] and WrLog("Error - Fail to retreive File $TmpRec->{FileName} from $SpmIP:",$OutPut[1],""),return 1;
	
	chomp($OutPut[0]);
	$OutPut[0] =~ s/>\s+</></g ;
	
	$XmlObjRec{$TmpRec->{FileName}}=XML::LibXML->new()->parse_string($OutPut[0]);
	my $SysID=$XmlObjRec{$TmpRec->{FileName}}->findvalue($TmpRec->{Xpath});
	my $ActSys;
	foreach my $SysRec ( @$SysList )
	{
		$SysRec->{SysID} == $SysID or next ;
		$ActSys=$SysRec;
		last;
	}
	ref($ActSys) or WrLog("Error - Actual SPM ($SpmIP) not belong to any system (SystemID: $SysID)"), return 1;
	delete $ParamsMaping{SysID};
	while ( my ($PKey,$PRec) = each (%ParamsMaping) )
	{
		exists ( $ActSys->{$PKey} ) and next;
		if ( exists $PRec->{Cmd} )
		{
			@OutPut=$TmpSesion->cmd($PRec->{Cmd});
			$OutPut[2] and WrLog("Error - Fail to run \"$PRec->{Cmd}\" at SPM $SpmIP (System $SysID)",$OutPut[1]),
																				$G_ErrorCounter++,$Err++,next;
			chomp($OutPut[0]);
			$OutPut[0] and $ActSys->{$PKey}=$OutPut[0];
		} else
		{
			unless ( exists $XmlObjRec{$PRec->{FileName}} )
			{
				@OutPut=$TmpSesion->cmd("cat $PRec->{FileName}");
				$OutPut[2] and WrLog("Error - Fail to Parse File $PRec->{FileName} at SPM $SpmIP (System $SysID)",$OutPut[1]),
																				$G_ErrorCounter++,$Err++,next;
				$XmlObjRec{$PRec->{FileName}}=XML::LibXML->new()->parse_string($OutPut[0]);
			}
			$ActSys->{$PKey}=$XmlObjRec{$PRec->{FileName}}->findvalue($PRec->{Xpath});
		}
	}
	return $Err;
}

sub SysLogFormat
{
	my $System=shift;
	ref $System or return;
	my @Result=("System \"$System->{Name}\" Details:","-" x 60);
	my @SysList=("SysID" ,
				 "NetworkDomain" ,
				 "DefaultMailDomain" ,
				 "BalancerList" ,
				 "MailEncryptMethod",
				 "TuiEncryptMethod" ,
				 "InternetEncryptMethod");
	my @TopologyList=( "ProfileLocator" ,
					   "ODS" ,
					   "MIPS" ,
					   "SPM" ,
					   "HTTP" ,
					   "VXV" ,
					   "NDS" );
	push ( @Result , map ( sprintf("\t%-15s: %s",$_,$System->{$_}) , @SysList ) );
	push (@Result ,"System \"$System->{Name}\" Topolgy:");
	push ( @Result , map (sprintf("\t%-15s: %s",$_,$System->{$_}) , @TopologyList) );
	return @Result ;
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

WrLog("Info  - Start Search all Systems Balancers ...");
my @Balancers=ReadBalancer($G_CLIParams{IP});
@Balancers or EndProg(1,"Fatal - No relevant Balancers Found at $G_CLIParams{IP}");
my $DefBalancer=$Balancers[0];
WrLog("Info  - Start Retreive GSL Structure from $DefBalancer ...");
my @SysList=ReadGSL($DefBalancer);
my ($DefSesion,@OutList,%BalancerMap);
WrLog("Info  - Detect Balancers of each system ....");
foreach my $IPBal (@Balancers)
{
	$DefSesion=Net::SSH::Perl->new($Balancers[0]);
	$DefSesion->login("root",q/Adm1Cmv4$/);
	@OutList=$DefSesion->cmd(q[perl -n -e '/domain/ and /(\S+)\s*$/ and print "$1\n"' /etc/resolv.conf]);
	$OutList[2] and WrLog("Error -  Fail to Determain Network Domain of $IPBal"),$G_ErrorCounter++,next;
	chomp $OutList[0];
	my $Flag=0;
	for ( my $i=0 ; $i < @SysList ; $i++ )
	{
		lc($SysList[$i]->{NetworkDomain}) eq lc($OutList[0]) or next;
		$Flag=1;
		$BalancerMap{$IPBal}=$i;
		$SysList[$i]->{BalancerList} .= exists $SysList[$i]->{BalancerList} ? ",$IPBal" : $IPBal ;
		### Retreive UnitGruop File ....  ##
		unless ( exists $SysList[$i]->{UnitGroup} )
		{
			@OutList=$DefSesion->cmd("cat $G_CLIParams{UnitGroupPath}");
			if ( $OutList[2] )
			{
				WrLog("Warning - Fail to Read UnitGroup of Balancer $IPBal ( System $SysList[$i]->{Name} )");
			} else
			{
				$SysList[$i]->{UnitGroup}=XML::LibXML->new()->parse_string($OutList[0]);
			}
		}
		last;
	}
	$Flag or WrLog("Error -  Fail to Determain System of $IPBal (NetworkDomain: $OutList[0])"),$G_ErrorCounter++;
}

WrLog("Info - Read Topology Info");

my %TopologySRec= ( ODS		=> ["Application","UnitInstance/\@DataIp"] ,
					Profile	=> ["Application","UnitInstance/\@DataIp"] ,
					ProfileLocator => ["Vapplication","VUnitInstance/\@VirtualIp"] ,
					NDS		=> ["Application","UnitInstance/\@DataIp"] ,
					VXV		=> ["Application","UnitInstance/\@DataIp"] ,
					HTTP	=>	["Vapplication","VUnitInstance/\@VirtualIp"] ,
					MIPS	=> ["Vapplication","VUnitInstance/\@VirtualIp"] ,
					SPM		=>  ["Application","UnitInstance/\@DataIp"] );
## WrLog("Debug - System info:");
my @SPMList;
foreach my $SysRecord (@SysList)
{
	### Search all Machines at System ###
	while ( my ($ServiceName,$ServicePath)=each(%TopologySRec) )
	{
		exists $SysRecord->{$ServiceName} or WrLog("Error - System \"$SysRecord->{Name}\" do not have $ServiceName"),
								$G_ErrorCounter++,next;
		my @IpNodes=$SysRecord->{UnitGroup}->findnodes(sprintf("//%s[\@ApplicationName=\"%s\"]/%s",
					$ServicePath->[0],$SysRecord->{$ServiceName},$ServicePath->[1]));
		@IpNodes and $SysRecord->{$ServiceName} .= ": ";
		foreach my $IpAddr (@IpNodes)
		{
			$SysRecord->{$ServiceName} .= sprintf(",%s",$IpAddr->value);
		}
	}
	#### Update SPM Info
	## WrLog("Debug - Update $ServiceName: $SysRecord->{$ServiceName} ");
	exists $SysRecord->{SPM} or next;
	WrLog("Info  - Read SPM Info from $SysRecord->{SPM}");
	my @List=split(/,/,$SysRecord->{SPM});
	while ( @List )
	{
		my $IpAddr=pop(@List ); 
		$IpAddr =~ /(\d+\.){3}\d+/ or next;
		$G_ErrorCounter += ReadSPM($IpAddr,\@SysList) or last;
		last ;
	}
}

foreach my $SysRecord (@SysList)
{
	my @Prntlist=SysLogFormat($SysRecord);
	WrLog(@Prntlist,'=' x 60,"","");
	exists $G_CLIParams{D} or next;
	WrLog("Debug  : SysRecord: $SysRecord");
	while ( my ( $PName,$PVal) = each(%$SysRecord) )
	{
		WrLog("\t-D- $PName : $PVal");
	}
	## exists $SysRecord->{SPM} and push(@SPMList,$SysRecord->{SPM});
}


my $ErrMessage= $G_ErrorCounter ? "Finish with ERRORS see Log File $G_CLIParams{LogFile}" :
		"Finish Successfully :-)";
EndProg($G_ErrorCounter,$ErrMessage);