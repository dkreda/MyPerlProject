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
				   SwimKitLocation	=> "/var/cti/data/swim/kits" );
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
   @Result=<INPUT>;
   $Err += $?;
   close INPUT ;
   $Err += $?;
   if ( $Err )
   {
   	WrLog("Error\tduring File reading error occurred.");
   	$G_ErrorCounter++;
   	return ;
   }
   chomp (@Result);
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

sub ReadMap ## FileName
{
	my $FName=shift;
	my %Result;
	foreach my $Line ( ReadFile($FName) )
	{
		$Line =~ /^\s*#/ and next;
		$Line =~ s/(\S+?)=// or next;
		$Result{$1}=[ split(/,/,$Line) ];
	}
	return %Result;
}

sub GetServers #$XmlDeployment
{
	my $XmlDeployment=shift;
	my %Result;
	foreach my $ServerElement ( $XmlDeployment->findnodes('//servergroup[properties/@type="sg"]') )
	{
		my $TmpNode=$ServerElement->getChildrenByLocalName("properties")->[0];
		my $Name=$TmpNode->getAttribute("name");
		my %ServerRec;
		$ServerRec{uuid}=$TmpNode->getAttribute("uuid");
		my %Macros;
		foreach $TmpNode ( $ServerElement->getChildrenByLocalName("macros") )
		{
			foreach my $AttrNode ( $TmpNode->attributes() )
			{
				$Macros{$AttrNode->nodeName}=$AttrNode->getValue();
			}
		}
		$ServerRec{Macros}=\%Macros;
		$Result{$Name} =\%ServerRec;
	}
	return %Result;
}

sub ExtractCommands  ## $TGUUID,$TaskName,\%TasksRec ,\%ExecRec
##
#  ExecRec = ( Commnds 	=>  \@Commds
#              Params	=>  \%Params
#			   Macros	=> \%Macros )
#
{
   my $TGroup=shift;
   my $TName=shift;
   my $TGsRec=shift;
   my $ExecRec=shift;
   my (@Result,$TmpStr,$ReplStr);
   ## WrLog("Debug - DepRec = $ExecRec , $ExecRec->{Macros} , $ExecRec->{Params} , $ExecRec->{Commnds} ");
   ## Check Task Pointers ###
   exists $TGsRec->{$TGroup} or WrLog("Error - TaskGroup with uuid \"$TGroup\" not found at this Marimba diployment file"), return;
   exists $TGsRec->{$TGroup}->{Tasks}->{$TName} or 
					WrLog("Error - Task Name \"$TName\" do not exists at TaskGroup $TGsRec->{$TGroup}->{Name} ($TGroup)"), return ;
   
   ####   Go Over the Macros and update the new value if needed ###
   while ( my ($MName,$Mval) =  each( %{$TGsRec->{$TGroup}->{Macros}} ) )
   {
	  if ( $Mval )
	  {
		 $ExecRec->{Macros}->{$MName}=$Mval;
	  } else
	  {
		$ExecRec->{Params}->{$MName}="String";  
	  }
   }
   foreach my $TCmd ( @{$TGsRec->{$TGroup}->{Tasks}->{$TName}} )
   {
		my $TmpLine=$TCmd;
		if ( $TmpLine =~ s/^task\s+// )
		{
			$TmpLine =~ s/\.(.+)$// or WrLog("Error - Illegal Reference command: $TCmd ") , next;
			$TmpStr=$1;
			ExtractCommands($TmpLine,$TmpStr,$TGsRec,$ExecRec);
		} else
		{
			while ( $TmpLine =~ /\%(\S+?)\%/ )
			{
				$TmpStr=$1;
				if ( exists $ExecRec->{Macros}->{$TmpStr} )
				{
					$ReplStr=$ExecRec->{Macros}->{$TmpStr};
				} else
				{
					$ReplStr="\{$TmpStr\}";
					$ExecRec->{Params}->{$TmpStr}="String";
				}
				$TmpLine=~s/\%$TmpStr\%/$ReplStr/g ;
			}
			if ( $TmpLine =~ /ds\s+-setMacros/ )
			{
				####   Extract  / update macros  ###
				my $OrigLine=$TmpLine ;
				while ( $OrigLine =~ s/(\S+?)=(\S+)// )
				{
					my ($MName,$MVals)=($1,$2);
					$ExecRec->{Macros}->{$MName}=$MVals;
				}
				## $TmpLine = " ## just update macro at Task $TGsRec->{$TGroup}->{Name} . $TName\n\t##Orig Line is: $TmpLine";
				$TmpLine = [ $TGroup , "\t#Just update macro (No actual command) at Task: $TGsRec->{$TGroup}->{Name} . $TName",
							 "\t#Orig Line is \"$TmpLine\"" ];
			}
			elsif ( $TmpLine =~ s/^system.+?=// )
			{
			    if ( $TmpLine =~ /Component_Stage.sh/ and ! exists $ExecRec->{Params}->{"Kits Location"} )
				{
					####  This is a Petch to support the Manual Stage of IS4 - if we use soft link to the Marimba Kit Location we can remove this Patch ...
					my $TargetDir=$G_CLIParams{SwimKitLocation} . "/{Kits Location}/IS4Kits/";
					$TargetDir =~ s/(^|[^\/])[\/]/$1\\\//g ;
					my @FileList=("/etc/cns/scripts/integ_utils/copy_kit_to_local_machine_linux_expect",
								  "/etc/cns/scripts/integ_utils/copy_kit_to_local_machine.sh" ,
								  "/etc/cns/scripts/integ_utils/copy_kit_to_local_machine_linux" );
					push(@{$ExecRec->{Commnds}},[$TGroup,"#This is a patch to support the Insight4 Copy - it fix the Kits location at the Copy/Stage Script"],
						     sprintf("perl -pi -e '/set\\s+REMOTE_KITS_PATH\\s/ and s/\\S+(\\s*)\$/$TargetDir\$1/' %s",join(' ',@FileList)),
"FileName=/etc/cns/scripts/integ_utils/copy_kit_to_local_machine.sh;perl -pi -e '/LOCAL_KITS_PATH\\S+KIT_NAME\\S+TEMP_CHECKSUM_FILE/ and s/^(\\s*(\\S+)){2}.+>/ perl -p -e \"s\\\/\^\.\+IS4Kits\\\\\\\/\\\/\\\/\" \$2>/' \$FileName || echo Skip");

  
					$ExecRec->{Params}->{"Kits Location"}="String";	
				}
			} else
			{
			    #WrLog("Warning - Unknown Type of command \"$TCmd\" at Task $TName TG: $TGroup");
				push(@{$ExecRec->{Commnds}},[$TGroup,"\t#Orig line of Task: $TGsRec->{$TGroup}->{Name} . $TName :",
							"\t#$TmpLine"]);
			}
			##  WrLog("\t-Debug update commad " . ($TmpLine =~ /\%(\S+?)\%/ ? "with Macro $1" : "No Macro found") );
			push(@{$ExecRec->{Commnds}},$TmpLine);
		} 
	}
   return 0;
}

sub GetTasks #$XmlDeployment
{
	my $XmlDeployment=shift;
	my %Result;
	foreach my $TaskGroup ( $XmlDeployment->findnodes('//taskgroup') )
	{
		my $TmpNode=$TaskGroup->getChildrenByLocalName("properties")->[0];
		my $UUID=$TmpNode->getAttribute("uuid"); 
		my (%TGRec,%Macros,%Task);
		my $StrVal=$TmpNode->getAttribute("name");
		$TGRec{Name}=$StrVal;
		$TmpNode=$TaskGroup->getChildrenByLocalName("macros")->[0];
		foreach my $Macro ( $TmpNode->attributes() )
		{
			$StrVal=$Macro->nodeName;
			$Macros{$StrVal}=$Macro->getValue();
		}
		$TGRec{Macros}=\%Macros;
		foreach my $Tasks ($TaskGroup->getChildrenByLocalName("task") )
		{
			$StrVal=$Tasks->getAttribute("name");
			my @Commands;
			foreach $TmpNode ( $Tasks->getChildrenByLocalName("command") )
			{
				push(@Commands,$TmpNode->textContent);
			}
			$Task{$StrVal}=\@Commands;
		}
		$TGRec{Tasks}=\%Task;
		$Result{$UUID}=\%TGRec;
	}
	return %Result;
}

sub MarinbaPath # $XmlDeployment - return string "the folder of this object"
{
   my $XmlDep=shift;
   ref($XmlDep) or return;
   my @TmpList=$XmlDep->getChildrenByTagName("properties");
   @TmpList or return;
   my $LocalName = $TmpList[0]->getAttribute("type") eq "folder" ? "/" . $TmpList[0]->getAttribute("name") : "" ;
   return MarinbaPath($XmlDep->parentNode) . $LocalName ;
}

sub BuildCaf # $Deployment,\%TGList,%Macros
{
	my $DepObj=shift;
	my $TGList=shift;
	my %MacroList=@_;
	my $CompVersion="First-Draft";
	my $CompOS="Linux";
	my $ExecCounter=1000;
	my $DepName=$DepObj->getChildrenByLocalName("properties")->[0]->getAttribute("name");
	my $TaskRef=$DepObj->getChildrenByLocalName("tgref")->[0]->getAttribute("uuid");
	
	unless ( exists $TGList->{$TaskRef} )
	{
		WrLog("Error - $DepName has unknown Task ! - Ignore ");
		$G_ErrorCounter;
		return ;
	}
	
	####  Get the Marimba Path  ####
	my $MarimbaPath=MarinbaPath($DepObj);
	my $CompName=$MarimbaPath ;
	$CompName =~ s/^.+[\/]// and $CompName = $DepName ."_" . $CompName ;
	my $Marimba=$DepObj->getOwner();
	my %TmpParams;
	my %DepRec=  (Commnds 	=>  [] ,
                  Params	=>  \%TmpParams ,
			      Macros	=>  \%MacroList );
	my @Commands;
	
	my $CAFXmlObj=XML::LibXML::Document->createDocument("1.0","UTF-8");
	my $Root=XML::LibXML::Element->new("SWIM");
	my $CompObj=$Root->appendChild(XML::LibXML::Element->new("Component"));
	$CompObj->setAttribute("Name",$CompName);
	$CompObj->setAttribute("Version",$CompVersion);
	$CompObj->setAttribute("Platform",$CompOS);
	$CAFXmlObj->setDocumentElement($Root);
	
	$CompObj->appendChild(XML::LibXML::Comment->new("This CAF File is implementation of $MarimbaPath/$DepName.$TGList->{$TaskRef}->{Name}"));
	
	my $InstallObj=$CompObj->appendChild(XML::LibXML::Element->new("Install"));
	my $ParamObj=XML::LibXML::Element->new("Parameters");
	##my $ParamObj=$CompObj->appendChild(XML::LibXML::Element->new("Parameters"));
	
	
	###  Go Over all Deployment Jobs  ####
	foreach my $ChNode ( $DepObj->getChildrenByLocalName("job") ) 
	{
	    my ($JName,$RefDep,$NextJob,$TmpJob);
		$TmpJob= $ChNode->getChildrenByLocalName("properties")->[0];
		$JName=$ChNode->getAttribute("name");
		$RefDep=$TmpJob->getAttribute("shortExternalName");
		$NextJob=$TmpJob->getAttribute("onSuccess");
		## WrLog(sprintf("%-30s|%-30s|%-30s",$JName,$RefDep,$NextJob));
		unless (  $RefDep =~ /^$DepName\.(.+)/ )
		{
			WrLog("\tWarning - Job $JName contains referens to other Deployment - Ignore it ...");
			next;
		}
		my $TmpStr=$1;
		ExtractCommands($TaskRef,$TmpStr,$TGList,\%DepRec);
	}
	## WrLog("Deploy $DepName ($MarimbaPath) commands:");
	foreach my $CmndLine ( @{$DepRec{Commnds}} )
	{
		if ( ref($CmndLine) ) 
		{
			my $TGPath=shift(@$CmndLine);
			my @Tmp=$Marimba->findnodes("//taskgroup[properties/\@uuid=\"$TGPath\"]");
			@Tmp or next;
			my $TGPath=MarinbaPath($Tmp[0]);
			# WrLog("\t # Comment: The following Line have been extracted from $TGPath",@$CmndLine);
			$InstallObj->appendChild(XML::LibXML::Comment->new("Note - The command below have been extracted from $TGPath"));
			@$CmndLine and $InstallObj->appendChild(XML::LibXML::Comment->new(join("\n",@$CmndLine)));
		} elsif ( $CmndLine =~ /http:\S+Marimba/ )
		{
			if ( $CmndLine =~ /-url\s+\S+?([^\/]+?)[\s|\"].+-dir\s+\"(.+?)\"/  )
			{
			## $CmndLine =~ /-url\s+\S+?([^\/]+?)[\s|\"].+(-dir)/ ;
				my ($Src,$Trg)=($1,$2);
			# WrLog("Copy command  Src=$Src , Target=$Trg");
				my $CopyEl=XML::LibXML::Element->new("Copy");
				$CopyEl->setAttribute("ExecutionOrder",$ExecCounter);
				$CopyEl->appendTextChild("Source", "./IS4Kits/$Src/*");
				$Trg =~ s/\s+$//;
				$CopyEl->appendTextChild("Target", $Trg);
				$InstallObj->appendChild($CopyEl);
			} elsif ( $CmndLine =~ /ds.onreboot./ )
			{
				my $ExcEl=$InstallObj->appendChild(XML::LibXML::Element->new("Reboot"));
				$ExcEl->setAttribute("ExecutionOrder",$ExecCounter);
			} else
			{
				my $ExcEl=$InstallObj->appendChild(XML::LibXML::Element->new("Execute"));
				$ExcEl->setAttribute("ExecutionOrder",$ExecCounter);
				$ExcEl->appendTextChild("Command",$CmndLine);
			}
			$ExecCounter+=5;
		} else
		{
			# WrLog($CmndLine);
			my $ExcEl=XML::LibXML::Element->new("Execute");
			$ExcEl->setAttribute("ExecutionOrder",$ExecCounter);
			$ExcEl->appendTextChild("Command",$CmndLine);
			$InstallObj->appendChild($ExcEl);
			$ExecCounter+=5;
		}
	}
	###### Update Parameter #####
	if ( keys(%{$DepRec{Params}})  )
	{
		my $ExcEl=XML::LibXML::Element->new("SetParams");
		$ExcEl->setAttribute("ExecutionOrder",100);
		my $SetName=$DepName . "_Parameters" ;
		$SetName =~ s/\s//g;
		$ExcEl->appendTextChild("ExecutionGroup",$SetName);
		$InstallObj->appendChild($ExcEl);
		foreach my $ParamName ( keys(%{$DepRec{Params}}) )
		{
			my $SingleParam=XML::LibXML::Element->new("Parameter");
			$SingleParam->setAttribute("Name",$ParamName);
			$SingleParam->setAttribute("ExecutionGroup",$SetName);
			$SingleParam->setAttribute("Level","System");
			my $Tmp=$SingleParam->appendChild(XML::LibXML::Element->new("Restrictions"));
			$Tmp->appendTextChild("Type","String");
			$ParamObj->appendChild($SingleParam);
		}
		$CompObj->appendChild($ParamObj);
	}
	$CAFXmlObj->toFile($CompName . "-CAF.xml" , 1);
	return $CompName;
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
my $Marimba=XML::LibXML->new()->parse_file($G_CLIParams{Dep});
#### Find all Deployment Objects #####
my %MapRec=ReadMap($G_CLIParams{Conf});
my %Servers=GetServers($Marimba);
#my $Counter=1;
#my @MenuTxt;
foreach my $Txt ( keys (%Servers) )
{
	exists $MapRec{$Txt} or WrLog("Warning - Missing Mapping for SG $Txt - Ignore this SG"),next;
	$Servers{$Txt}->{UnitType}=$MapRec{$Txt}->[0];
	$Servers{$Txt}->{OS}=$MapRec{$Txt}->[1];
	#push(@MenuTxt,sprintf("%2d $Txt",$Counter));
	#$Counter++;
}
#WrLog("Servers List:",@MenuTxt,"Select Server to show:");
#my $In=<STDIN>;
#exists $MenuTxt[$In-1] or EndProg(1,"Out of Range ...");
#$MenuTxt[$In-1] =~ /(\S+)$/ and $Counter=$1;

#WrLog("Server $Counter:","uuid = $Servers{$Counter}->{uuid}");
#while ( my ($MName,$MVal) = each(%{$Servers{$Counter}->{Macros}}) )
#{
#	WrLog( "\t$MName = $MVal");
#}

my %Tasks=GetTasks($Marimba);

foreach my $SGName ( keys(%Servers) )
{
exists $Servers{$SGName}->{UnitType} or next;
my $UAFXmlObj=XML::LibXML::Document->createDocument("1.0","UTF-8");
my $UAFCompObj=XML::LibXML::Element->new("SWIM");
$UAFXmlObj->setDocumentElement($UAFCompObj);
$UAFCompObj=$UAFCompObj->appendChild(XML::LibXML::Element->new("UnitType"));
my $UnitType=$Servers{$SGName}->{UnitType};
$UAFCompObj->setAttribute("Name",$UnitType);
$UAFCompObj->setAttribute("Platform",$Servers{$SGName}->{OS});
$UAFCompObj->appendChild(XML::LibXML::Comment->new("This UAF is implementation of Marimba ServerGroup $SGName"));
$UAFCompObj=$UAFCompObj->appendChild(XML::LibXML::Element->new("Install"));

foreach my $DepObj ( $Marimba->findnodes("//deployment[sgref/\@uuid=\"$Servers{$SGName}->{uuid}\"]") )
{
	my $CompName = BuildCaf($DepObj,\%Tasks,%{$Servers{$SGName}->{Macros}});
	unless ( $CompName )
	{
		WrLog("Error - fail to set CAF File for Deployment - Uaf File will not include the deployment");
		next;
	}
	my $CompObj=XML::LibXML::Element->new("Component");
	$CompObj->setAttribute("Name",$CompName);
	$CompObj->setAttribute("ExecutionOrder",10);
	$UAFCompObj->appendChild($CompObj);
}

$UAFXmlObj->toFile("$UnitType-UAF.xml",1);
}

my $ErrMessage= $G_ErrorCounter ? "Finish with ERRORS see Log File $G_CLIParams{LogFile}" :
		"Finish Successfully :-)";
EndProg($G_ErrorCounter,$ErrMessage);