#!/usr/cti/apps/CSPbase/Perl/bin/perl
##############################################################################
# This Scripts Update scdb as follow:
# 1. merge templates with scdb
# 2. Add New Units (MMSGW,Proxy and NDU-WHC) to scdb
# 3. Generate Unit Group and distribute UnitGroups ....
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
my %G_CLIParams=(	LogFile  	=> "-" ,
					TemplateFolder	=> "/tmp" ,
					ScdbBin	=> "/usr/cti/apps/scdb/bin" ,
					ScdbCLi	=>	"/usr/cti/apps/scdb/bin/scdbCli.sh" );
					
my $G_ScdbFile;    ## ="/opt/CMVT/scdb/data/scdb.xml";
my %G_EnvParams;
my @G_RollBackList=();
my @G_FileHandle=();

sub usage
{
	my $Script= $0 =~ /([^\\\/]+)$/ ? $1 : $0 ;
	print "$Script -SysName \"System Name\" -PVVM \"PVVM Type\" -Type \"Installation/system type\" -Service \"List of services\" -UnitGroup \"UnitGroup File\" -Map \"csv file\"\n";
	print "\t optional Parameters: [-Ver \"version\"] [-DefSCDB \"Default scdb file\"] [-TemplateFolder \"Location of all Scdb Templates\"] [-ScdbBin \"Binarry Folder\"]\n";
	print "\t                      [-ScdbCLi \"Cli command\"] [-LogFile FileName] [-D]\n";
    print "$Script -help\n";
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
   if ( RunCmds("perl -MExtUtils::Command -e cp $OrigFile $BackFile",
				"chown --reference=$OrigFile $BackFile",
				"chmod --reference=$OrigFile $BackFile" ) )
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
}

sub CliCmdBuilder 
###############################################################################
#
# Input:         \%UnitRecord :
#                Object => The object where the unit should be add
#				 UnitName => host name of the unit
#				 IP   =>     IP of the machine.
#
# Return:		%Setof_Coomands:
#				addUnit
#				addConn
#				retrieve
#				
# Description:	Build comand line for scdb CLI
#
###############################################################################
{
    my $ScdbVer=$G_EnvParams{ScdbVersion};
    ## my $CmdName=shift;
    my $UnitRecP=shift;
    my %AttrMap=("System"	=> $G_CLIParams{SysName} ,
    		 Object		=> $$UnitRecP{Object} ,
    		 UnitName	=> $$UnitRecP{UnitName} ,
    		 MacAddress	=> "\'N/A\'"	,
    		 ManualInactive	=> "\'0\'"	,
    		 Type		=> "Data"	,
			 newType    => "Data"   ,
			 ConnectionType	=> "Data"	,
    		 IP		=> $$UnitRecP{IP} ,
    		 Hostname	=> $$UnitRecP{UnitName} ,
    		 NewUnitName	=> $$UnitRecP{UnitName} ,
    		 newHostname	=> $$UnitRecP{UnitName} );

     ### SCDB 5.0.0.0 (DOC-0-049-117) - SCDB 5.2.0.0 (DOC-0-053-433) ###    		   
     my %Scdb_Ver1 = (addUnit	=> ["add UnitInstance","Object","UnitName","MacAddress","ManualInactive"] ,
    		   addConn	=> ["add Connection","Object","UnitName","ConnectionType","IP","Hostname"],
    		   retrieve	=> ["retrieve UnitInstance","Object","UnitName"] ,
    		   "Delete"	=> ["delete UnitInstance","Object","UnitName"] ,
    		   updateUnit	=> ["update UnitInstance","Object","UnitName","NewUnitName","MacAddress","ManualInactive"] ,
    		   updateConn	=> ["update Connection","Object","UnitName","newHostname","Type","IP","Hostname"] );
    		   
	### SCDB 5.2.2.0 (DOC-0-050-934) - SCDB 5.4.0.1 (DOC-0-082-692) ###    		   
     my %Scdb_Ver2 = (addUnit	=> ["add UnitInstance","Object","UnitName","MacAddress","ManualInactive"] ,
    		   addConn	=> ["add Connection","Object","UnitName","Type","IP","Hostname"],
    		   retrieve	=> ["retrieve UnitInstance","Object","UnitName"] ,
    		   "Delete"	=> ["delete UnitInstance","Object","UnitName"] ,
    		   updateUnit	=> ["update UnitInstance","Object","UnitName","NewUnitName","MacAddress","ManualInactive"] ,
    		   updateConn	=> ["update Connection","Object","UnitName","newHostname","Type","IP","Hostname"] );		   
    		   
    ### SCDB 5.5 (DOC-0-075-938)
	### SCDB 5.6.0.0 (DOC-0-090-359)
	###SCDB5.6.1.1(DOC-0-097-709)SCDB5.6.2.0(DOC-0-099-915)SCDB5.6.3.0(DOC-0-102-051)SCDB6.0.0.0(DOC-0-099-921)SCDB6.1.0.0(DOC-0-111-348)		
    my %Scdb_Ver3 = (addUnit	=> ["add UnitInstance","Object","System","UnitName","MacAddress","ManualInactive"] ,
    		   addConn	=> ["add Connection","Object","System","UnitName","Type","IP","Hostname"],
    		   retrieve	=> ["retrieve UnitInstance","Object","System","UnitName"] ,
    		   "Delete"	=> ["delete UnitInstance","Object","System","UnitName"] ,
    		   updateUnit	=> ["update UnitInstance","Object","System","UnitName","NewUnitName","MacAddress","ManualInactive"] ,
    		   updateConn	=> ["update Connection","Object","System","UnitName","newHostname","Type","IP","Hostname"] );
    
	###SCDB5.6.1.1(DOC-0-097-709)SCDB5.6.2.0(DOC-0-099-915)SCDB5.6.3.0(DOC-0-102-051)SCDB6.0.0.0(DOC-0-099-921)SCDB6.1.0.0(DOC-0-111-348)	 
    my %Scdb_Ver4 = (addUnit	=> ["add UnitInstance","Object","System","UnitName","MacAddress","ManualInactive"] ,
    		   addConn	=> ["add Connection","Object","System","UnitName","Type","IP","Hostname"],
    		   retrieve	=> ["retrieve UnitInstance","Object","System","UnitName"] ,
    		   "Delete"	=> ["delete UnitInstance","Object","System","UnitName"] ,
    		   updateUnit	=> ["update UnitInstance","Object","System","UnitName","NewUnitName","MacAddress","ManualInactive"] ,
    		   updateConn	=> ["update Connection","Object","System","UnitName","newType","Type","IP","Hostname"] );
			   
    my (%NulScdb,%Result,$ErrFlag);
    		   
    my %ScdbCmds=(None 	    =>   \%NulScdb ,
    		  "5.x.x.x" =>   \%Scdb_Ver1 ,
    		  "5.1.x.x" =>	 \%Scdb_Ver1 ,
    		  "5.2.x.x" => 	 \%Scdb_Ver1 ,
    		  "5.2.2.x" => 	 \%Scdb_Ver2 ,
    		  "5.3.x.x" => 	 \%Scdb_Ver2 , 
			  "5.4.x.x" =>   \%Scdb_Ver2 ,
    		  "5.5.x.x" =>	 \%Scdb_Ver3 ,
    		  "5.6.x.x" => 	 \%Scdb_Ver3 ,
    		  "5.6.1.x" => 	 \%Scdb_Ver3 ,
    		  "5.6.2.x" => 	 \%Scdb_Ver4 , 
			  "5.6.3.x" => 	 \%Scdb_Ver4 ,
    		  "6.x.x.x" => 	 \%Scdb_Ver4 ,
    		  "6.1.x.x" => 	 \%Scdb_Ver4 ) ;
    		  
    exists $ScdbCmds{$ScdbVer} or WrLog("Error - Unsuported Scdb Version $ScdbVer") , return;
    my %CmdDef=%{$ScdbCmds{$ScdbVer}};
    while ( my ($CmdName,$ParamList) = each(%CmdDef) )
    {
    	undef $ErrFlag;
    	## $ParamList=$CmdDef{$CmdName}
    	for ( my $Indx=$#$ParamList ; $Indx > 0 ; $Indx-- )
    	{
    	    exists $AttrMap{$$ParamList[$Indx]} or $ErrFlag=$$ParamList[$Indx], last;
    	    my $ParamName=$$ParamList[$Indx];
    	    ## WrLog("Debug - setting parameter value of $ParamName");
    	    $$ParamList[$Indx].="=$AttrMap{$ParamName}";
    	}
    	if ( defined $ErrFlag )
    	{
    	   WrLog("Error - Internal Error at script. scdb command Builder do not recognize parameter \"$ErrFlag\"");
    	   while ( my ($DD,$HH) = each(%AttrMap) )
    	   {
    	   	WrLog(" - \"$DD\" -> $HH");
    	   }
    	   $G_ErrorCounter++;
    	   return ;
    	}
    	$Result{$CmdName}=join(" ",@$ParamList);
    }
    return %Result;
}

sub GenAddUnitsToSCDB
###############################################################################
#
# Input:         %UnitRecord :
#                $UnitRecord{Object}  UnitName IP [SysName]
#
# Return:
#
# Description:
#
###############################################################################
{
    my %UnitRec=@_;
    my $ScdbCmdPreffix="su - scdb_user -c";
    my $ScdbUtil="$G_CLIParams{ScdbBin}/scdbCli.sh"; #   "/usr/cti/scdb/bin/scdbCli.sh";
    my @ExecCmds ;
    ### my $SysParam= defined $UnitRec{SysName} ? "System=$UnitRec{SysName}" : "";
	## WrLog("DDDDDDDDDDDDDBUG function GenAddUnitsToSCDB Line :",__LINE__,%UnitRec,"","");
    my %ScdbCmds=CliCmdBuilder(\%UnitRec);
    exists $ScdbCmds{retrieve} or return;
    ### Check if this instance already exists   ###
    WrLog("Info - Check if $UnitRec{UnitName} alreday exist in scdb. (please ignore the error)");
    unless ( system("$ScdbCmdPreffix \"$ScdbUtil $ScdbCmds{retrieve}\"") )
    {
    	@ExecCmds=("$ScdbCmdPreffix \"$ScdbUtil $ScdbCmds{updateUnit}\"" ,
    		  "$ScdbCmdPreffix \"$ScdbUtil $ScdbCmds{updateConn}\"" );
    }else 
    {
     	@ExecCmds=("$ScdbCmdPreffix \"$ScdbUtil $ScdbCmds{addUnit}\"" ,
    		  "$ScdbCmdPreffix \"$ScdbUtil $ScdbCmds{addConn}\"" );
    }
    return RunCmds(@ExecCmds);
}

sub AddUnits
###############################################################################
#
# Input:	\%UnitList
#
# Return:
#
# Description:
#
###############################################################################
{
   my $UnitList=shift;
   my $Err=0;
   while ( my ($UnitIP,$UnitParams) = each(%$UnitList) )
   {
	$UnitParams->{IP}=$UnitIP;
	## $UnitParams->{SysName}=$G_CLIParams{SysName};
	$Err += GenAddUnitsToSCDB(%$UnitParams);
   }
   return $Err;
}

sub AddUnits_OldScdb
###############################################################################
#
# Input:	%UnitList,\%ExtarConfig
#
# Return:
#
# Description:  AddUnits to Old Version SCDB. after adding Units update
#				Extra configuration such as disply=0/1 etc ...
#
###############################################################################
{
   my $UnitList=shift;
   my $ExtarConfig=shift;
   my $Err=0;
   while ( my ($UnitIP,$UnitParams) = each(%$UnitList) )
   {
	$UnitParams->{IP}=$UnitIP;
	$Err += GenAddUnitsToSCDB(%$UnitParams);
   }
   ### Update ExtraConfiguration  ###
   ### Set Extra Data 
   my $XmlObj=XML::LibXML->new()->parse_file($G_ScdbFile);
   unless ( SetExtraSettings($XmlObj,$ExtarConfig,$G_ScdbFile) )
   {
		$Err += $XmlObj->toFile($G_ScdbFile,1) ? 0 : 1;
		## $Err += RunCmds("chmod 666 $TargetFile");
   }
   return $Err;
}

sub NullCmd
{
   WrLog("Info - @_. Excute Null command.");
   return 0;
}

sub SCDBMerge
###############################################################################
#
# Input:	$Source
#
# Return:	0 - O.K , 1 - Error
#
# Description:
#
###############################################################################
{
    my $Source=shift;
    my $ScdbCmd="su - scdb_user -c \"$G_CLIParams{ScdbBin}/scdb.sh Merge -to $G_ScdbFile -from $Source\"";
    return RunCmds($ScdbCmd);
}


sub RollBack
###############################################################################
#
# Input:
#
# Return:
#
# Description:  Roll back all Changed Files ...
#
###############################################################################
{
    my @CmdList=();
    foreach my $FileName ( @G_RollBackList )
    {
    	my $OrigFile=$FileName;
    	$OrigFile =~ s/\.Backup_[^\.]+$// or WrLog("-- Fail To Restore To Original $OrigFile"),next;
		my $FName=$OrigFile ;
		$FName =~ s/.+\///;
    	push(@CmdList,"mv -f $FileName $OrigFile");
    }
    return RunCmds(@CmdList);
}

sub ValidateSCDB
###############################################################################
#
# Input:
#
# Return:
#
# Description:  0 - O.K   ,  1 - Error
#
###############################################################################
{

    my @ErrLog=`su - scdb_user -c "$G_CLIParams{ScdbBin}/scdb.sh validate"`;
    chomp(@ErrLog);
    unless ( grep(/Your file is valid/,@ErrLog) )
    {
    	WrLog("Error - Scdb is not Valid:",@ErrLog);
    	return 1;
    }
    WrLog("Info - SCDB is Valid.");
    return 0;
}

sub ScdbGenerate
###############################################################################
#
# Input:
#
# Return:
#
# Description: Generate + Distribute UnitGroup and SCDB
#
###############################################################################
{
    my $ScdbCmd="su - scdb_user -c \"$G_CLIParams{ScdbBin}/scdb.sh ";
    my $ScdbFolder=$G_ScdbFile;
	my $DistList=shift;
    $ScdbFolder =~ s/\/[^\/]*$// ;
    my @UnitGroups=`find $ScdbFolder -name UnitGroup.xml`;
    chomp @UnitGroups;
    foreach my $FileName (@UnitGroups)
    {
    	push(@G_RollBackList,BackupFile($FileName));
    }
    my $Err=RunCmds($ScdbCmd . "UnitGroupGenerator all\"");
    if ( $Err )
    {
    	WrLog("Error - Fail to Generate Unit Group. Skip Distribution");
    	return 1;
    }
	my @Cmds=map { $ScdbCmd . "$_ all\"" } @$DistList;
	return RunCmds(@Cmds);
}

sub ParseUnitGroup
###############################################################################
#
# Input:	$UnitFile - Ful Path of the Unit Group file to parse
#
# Return:	%UnitRecord :
#			Key (IP)  =>   { UnitName => Machine Name ( host name )
#							 Object	  => UnitType (Example OMU_Unit,CAS_Unit)
#							 Group	  => Phosical UnitGroup as apeara at UnitGroup.xml }
#
# Description: Parse UnitGroup.xml file and build UnitRecord
#
###############################################################################
{
	my $UnitFile=shift;
	my %SCDBObj=@_;
	unless ( -e $UnitFile )
	{
		WrLog("Error - could not find file $UnitFile");
		$G_ErrorCounter++;
		return ;
	}
   my %Result;
   my $UnitGroupXml=XML::LibXML->new()->parse_file($UnitFile);
   
   foreach my $UnitXml ( $UnitGroupXml->findnodes("//Physical") )
   {
		my $GroupName=$UnitXml->getAttribute("GroupName");
		my $UnitType=$GroupName;
		$UnitType =~ s/Group/Unit/ or $UnitType .= "_Unit";
		foreach my $UnitInstace ( $UnitXml->getChildrenByLocalName("UnitInstance") )
		{
			my (%TempRec,$UIP,$UName);
			$UIP=$UnitInstace->getAttribute("DataIp");
			$UName=$UnitInstace->getAttribute("Hostname");
			$Result{$UIP} = { UnitName	=> $UName ,
							  Object	=> $UnitType ,
							  Group		=> $GroupName } ;
			
		}
   }
   return %Result;
}

sub SCDBpostInstall
###############################################################################
#
# Input:
#
# Return:
#
# Description:
#
###############################################################################
{
    my %UnitList=@_;
    my $FileName="/etc/hosts";
    my @IpLists=ReadFile($FileName);
    my @AddHosts=();
    foreach my $IpAddress (keys(%UnitList) )
    {
    	grep(/$IpAddress\s/,@IpLists) and next;
    	push(@IpLists,"$IpAddress $UnitList{UnitName}.MMEG");
    }
    push(@G_RollBackList,BackupFile($FileName));
    return WriteFile($FileName,@IpLists);
}

sub SetExtraSettings
###############################################################################
#
# Input:	$XmlObj,\%ExtraSetting,$TargetFileName
#	  $XmlObj - Perl XML::LibXML object that contain the relevant scdb content.
#	  %ExtraSetting - Hash of Key=Xpath , Value = the value to change 
#	  $FileName - Name / path of File to change (This is only for debug messages)
#
# Return:	0 - O.K ,  1 - Error
#
# Description:  Set Parameter at SCDB or Template acording to ExtarSetting input
#
###############################################################################
{
	my $XmlObj=shift;
	my $ExtraSetting=shift;
	my $TargetFileName=shift;
	my $ScdbPath=$G_ScdbFile;
	$ScdbPath =~ s/[[\/]?[^\/]+$// ;
	my $Err=0;
	while ( my ($Xpath,$XValue) = each (%$ExtraSetting) )
	{
		if ( $XValue =~ s/(.+?)::\//\// )
		{
			### The Value of This Xpath is reference to other Xml File
			my $FileName= -e $1 ? $1 : "$ScdbPath/$1" ;
			-e $FileName or WrLog("Error - File \"$FileName\" Not Exists !"),$Err++,next;
			my $TmpXMLObj=XML::LibXML->new()->parse_file($FileName);
			$XValue=$TmpXMLObj->findvalue($XValue);
		}
		if ( $Xpath =~ s/\/\@([^\/\[\]]+)$// )
		{
			## This is Attrbute Node
			my $AttrName=$1;
			my @TmpNode=$XmlObj->findnodes($Xpath);
			@TmpNode or WrLog("Warning - Element \"$Xpath\" not exists at \"$TargetFileName\""),next;
			exists $G_CLIParams{D} and WrLog("Debug - UpDate all $Xpath instances");
			foreach my $Node (@TmpNode)
			{
				$Node->setAttribute($AttrName,$XValue);
				exists $G_CLIParams{D} and WrLog("Debug - Update Attribute $AttrName with $XValue");
			}
		} else
		{
			### Setting Element
			my @TmpNode=$XmlObj->findnodes($Xpath);
			@TmpNode or WrLog("Warning - Element \"$Xpath\" not exists at \"$TargetFileName\""),next;
			exists $G_CLIParams{D} and WrLog("Debug - UpDate all $Xpath instances (Elements)");
			my $NodeName=$TmpNode[0]->nodeName;
			my $NewNode=XML::LibXML::Element->new($NodeName);
			$NewNode->appendText($XValue);
			foreach my $Node (@TmpNode)
			{
				$Node->replaceNode($NewNode->cloneNode(1));
			}
		}
	}
	return $Err;
}

sub SetTemplateData
###############################################################################
#
# Input:	$SourceFile,$TargetFile,$SytemName,\%ExtraSetting
#	  $SourceFile - Temlate File That should be Merge into scdb.
#	  $TargetFile - The File That should be create This file looks like 
#			the Temlate File - But is update with the system name.
#	  $SytemName  - The System name that should be merged.
#
# Return:	0 - O.K ,  1 - Error
#
# Description:  Set Temlate file to be update with system name etc ...
#
###############################################################################
{
    my ($SourceFile,$TargetFile,$SytemName,$ExtraSetting)=@_;
    my $SourceXml = XML::LibXML->new()->parse_file($SourceFile);
	my $SCDBXml = XML::LibXML->new()->parse_file($G_ScdbFile);
	my $Err=0;
	WrLog("Info - Customizing Template file. using Template $SourceFile");
	my @NodeList = $SCDBXml->findnodes("//SystemRoot[\@SystemName=\"$SytemName\"]");
	@NodeList or WrLog("Error - Fail to found Matching system \"$SytemName\" at scdb.") , return 1;
	my @TargetNodes= $SourceXml->findnodes("//SystemRoot");
	@TargetNodes or WrLog("Error - Template File \"$SourceFile\" do not have systemRoot Element") , return 1;
	my ( $Source,$Target ) = ($NodeList[0],$TargetNodes[0]);
	for ( my $i=1 ; $i <=2 ; $i++ )
	{
		foreach my $Attr ( $Source->attributes() )
		{
			$Target->setAttribute($Attr->getName,$Attr->getValue);
			exists $G_CLIParams{D} and WrLog(sprintf("Debug Update Template: %s = %s",$Attr->getName,$Attr->getValue));
		}	
		$Source= $Source->parentNode ;
		$Target = $Target->parentNode ;
	}
	
	### Set Extra Data 
	unless ( SetExtraSettings($SourceXml,$ExtraSetting,$SourceFile) )
	{
		$Err += $SourceXml->toFile($TargetFile,1) ? 0 : 1;
		$Err += RunCmds("chmod 666 $TargetFile");
	}
	return $Err;
}

sub PickSystemVars ##@InstalationOp
###############################################################################
#
# Input:	@InstalationTypes
#			list of available installation types.
#
# Return:	%ScdbParametrs:
#			   PvvmType	=> one of the Enums "insight3,insight4,insight5"
#              ScdbVersion => SCDB version.
#			   SystemNames => [List]  List of the systems in scdb.xml
#			   ScdbType	   => Single or Distribute
#
# Description:  Set some parameters from the local scdb components.
#
###############################################################################
{
    my @InstalationOp=@_;
    my %Result = ( PvvmType	=> ( $G_CLIParams{PVVM} =~ /InSight4/i ? "insight4" : $G_CLIParams{PVVM} ) );
    ####    Get SCDB Version   ####
    WrLog("Info - Reading SCDB Version ...");
	my $XmlObj= -e $G_ScdbFile ? XML::LibXML->new()->parse_file($G_ScdbFile) : XML::LibXML->new()->parse_string("<Identification><ComponentRelease/></Identification>");
    my $ScdbVer=exists $G_CLIParams{Ver} ? $G_CLIParams{Ver} : $XmlObj->findvalue("//Identification/ComponentRelease");
    WrLog("Info - SCDB version: $ScdbVer");
    my $IntVer=0;
    "$ScdbVer.0.0.0" =~ /((\d+\.){2}\d+)/ and $ScdbVer=$1;
    foreach my $Octec ( split(/\./,$ScdbVer) )
    {
    	$IntVer= $IntVer*100+$Octec;
    }
	my %RangeMap = ( 60100	=> "6.1.x.x" ,
					 60000	=> "6.x.x.x" ,
					 50603	=> "5.6.3.x" ,
					 50602	=> "5.6.2.x" ,
					 50601	=> "5.6.1.x" ,
					 50600	=> "5.6.x.x" ,
					 50500	=> "5.5.x.x" ,
					 50400	=> "5.4.x.x" ,
					 50300	=> "5.3.x.x" ,
					 50202	=> "5.2.2.x" ,
					 50200	=> "5.2.x.x" ,
					 50100	=> "5.1.x.x" ,
					 50000	=> "5.x.x.x"  
					) ;
	my @TmpList=sort(keys(%RangeMap));
	for (  my $i=$#TmpList; $i >=0 ; $i-- )
	{
		$IntVer < $TmpList[$i] and next;
		$Result{ScdbVersion}=$RangeMap{$TmpList[$i]};
		last;
	}
	exists $Result{ScdbVersion} or $Result{ScdbVersion}="None" ;
    
    ##  Check SCDB Type  (Distribute or Single ) ###
    WrLog("Info - Check SCDB Type ...");    		       
    unless ( $Result{ScdbType} eq "None" )
    {
    	my @SysNames=`su - scdb_user -c "$G_CLIParams{ScdbBin}/scdbCli.sh get Systems" | grep "Parent Object name"` ;
    	chomp @SysNames;
		while ( $? ) { system ("echo") }
    	$Result{ScdbType} = $#SysNames > 0 ? "Distribute" : "Single" ;
    	$Result{SystemNames}=\@SysNames;
    	WrLog("Info - Change SCDB type to $Result{ScdbType}");
    }
    ### Resolve Installation Type ###
	## This is only for backward compatible ##
	#  Installation Type may be define via -Type Type  or -MainSite etc ... #
    WrLog("Info - Resolving Installation Type ...");
    $Result{InstallType}="UnKNown";
    foreach (@InstalationOp)
    {
    	exists $G_CLIParams{$_} and $Result{InstallType}=$_ , last;
    }
	exists $G_CLIParams{Type} and $Result{InstallType}=$G_CLIParams{Type};
    return %Result;
}

sub ReadMapFile #$FileName,$ScdbType(Single/Distribute),$PVVMType(Insight3,Is4 etc)
{
	my ($FileName,$ScdbType,$PvvmType)=@_;
	my @Content=ReadFile($FileName);
	###  Check Title
	my @Fields=split(/,/,shift(@Content));
	my $ColumNum;
	for ( $ColumNum=2 ; $ColumNum < @Fields ; $ColumNum++ )
	{
		exists $G_CLIParams{D} and WrLog("Debug - Parsing Column $ColumNum : $Fields[$ColumNum]");
		lc($Fields[$ColumNum]) eq lc($PvvmType) and last;
	}
	if ( $ColumNum >= @Fields )
	{
		my @Message=("Error - \"$PvvmType\" is not part of legal PVVM Values. Available values:",
					 sprintf("\t%s",join(",",@Fields[2..$#Fields])) );
		$G_ErrorCounter++;
		WrLog(@Message);
		exists $G_CLIParams{D} and WrLog("Debug - csv file Title:",@Fields);
		return;
	}
	my %Result;
	foreach my $Line ( @Content )
	{
		##while ( $Line =~ s/(\"[^\"]+?),([^\"]+?\")/$1:<>:$2/ ) {}
		##$Line =~ s/\"//g;
		@Fields=split(/,/,$Line);
		lc($Fields[1]) eq lc($ScdbType) or next;
		length($Fields[$ColumNum]) > 0 or next;
		foreach my $Service ( split(/;/,$Fields[$ColumNum] ) )
		{
			$Result{$Service}=$Fields[0];
		}
		exists $G_CLIParams{D} and WrLog("Debug - Add Line \"$Line\" to Map Record");
	}
	return %Result;
}

sub GetSCDBPath
{
	exists $G_CLIParams{DefSCDB} and return $G_CLIParams{DefSCDB} ;
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
	-d $Result and $Result .="/scdb.xml";
	WrLog("Info - SCDB Path is $Result");
	return $Result;
}

sub ScdbFactory
###############################################################################
#
# Input:	%UnitListRec
#
# Return:	%ScdbFactory
#
# Description:  Setup Parameers acording to system ...
#
###############################################################################
{
	my %UnitListRec=@_;
	my %Result;
    my %InstallType= ( MainSite	=> 0 , NonMain	=> 0 , DCSite	=> 1 , Embeded	=> 1 );
     
	if ( $G_CLIParams{Service} =~ s/file://i )
	{
		-e $G_CLIParams{Service} or WrLog("Error - Fail to find service file definition \"$G_CLIParams{Service}\""),$G_ErrorCounter++,return;
		my @Lines=ReadFile($G_CLIParams{Service});
		$G_CLIParams{Service}=join(",",@Lines);
		$G_CLIParams{Service} =~ s/\s+$//;
		$G_CLIParams{Service} =~ s/^\s+//;
		$G_CLIParams{Service} =~ s/\s+/,/g;
	}
    #	    0.ScdbMerge , 1.buildTemplate , 2. AddUnits
	my @AppList=( [\&NullCmd,\&NullCmd,\&NullCmd] ,  ## NoScdb
			      [\&NullCmd,\&NullCmd,\&AddUnits_OldScdb ] ,  ## Old Version applcation 
				  [\&SCDBMerge,\&SetTemplateData,\&AddUnits] ## New version applications
				  );
    my %ScdbVerRes= ( None => 	[\&NullCmd,\&NullCmd,\&NullCmd,[]]  ,
    		      "5.x.x.x" => [\&NullCmd,\&NullCmd,\&AddUnits_OldScdb,["UnitGroupDistributor"]] ,
    		      "5.1.x.x" => [\&NullCmd,\&NullCmd,\&AddUnits_OldScdb,["UnitGroupDistributor"]] ,
				  "5.2.x.x" => [\&NullCmd,\&NullCmd,\&AddUnits_OldScdb,["UnitGroupDistributor"]] ,
				  "5.2.2.x" => [\&NullCmd,\&NullCmd,\&AddUnits_OldScdb,["UnitGroupDistributor"]] ,
				  "5.3.x.x"	=> [\&NullCmd,\&NullCmd,\&AddUnits_OldScdb,["UnitGroupDistributor"]] ,
    		      "5.4.x.x" => [\&NullCmd,\&NullCmd,\&AddUnits_OldScdb,["UnitGroupDistributor"]] ,
				  "5.5.x.x" => [\&SCDBMerge,\&SetTemplateData,\&AddUnits,["UnitGroupDistributor"]] ,
				  "5.6.x.x" => [\&SCDBMerge,\&SetTemplateData,\&AddUnits,["UnitGroupDistributor"]],
				  "5.6.1.x" => [\&SCDBMerge,\&SetTemplateData,\&AddUnits,["UnitGroupDistributor"]] ,
				  "5.6.2.x" => [\&SCDBMerge,\&SetTemplateData,\&AddUnits,["UnitGroupDistributor"]] ,
    		      "5.6.3.x"	=> [\&SCDBMerge,\&SetTemplateData,\&AddUnits,["UnitGroupDistributor"]] ,
				  "6.1.x.x"	=> [\&SCDBMerge,\&SetTemplateData,\&AddUnits,["UnitGroupDistributor","ScdbFileDistributor"]] ,
				  "6.x.x.x" => [\&SCDBMerge,\&SetTemplateData,\&AddUnits,["UnitGroupDistributor","ScdbFileDistributor"]] );				  

    # 0.AddApp , 1.TemplateFile->scdbType2..3 , 2. PostInstall		      
    my %ScdbPvvmRes= ( insight4	=>  [{},\&NullCmd],
    		           insight3	=>  [{},\&SCDBpostInstall] ,
					   insight5	=>  [{ "//Application[\@ApplicationName=\"ODS_CALLS\"]/\@HostingUnits" => 
											"scdb.xml:://Application[\@ApplicationName=\"ODS\"]/\@HostingUnits"  } ,\&NullCmd] );

        ## Find scdb File

	%G_EnvParams=PickSystemVars(keys %InstallType); 
	
	### Check if Init is O.K ###
    
    my @Message=("Info - System / Envaironment Parameters:" ) ;
    
    foreach my $Param ("PvvmType","ScdbType","InstallType","ScdbVersion")
    {
    	push(@Message,"\t$Param: $G_EnvParams{$Param}");
    	exists $G_EnvParams{$Param} and next;
    	$G_ErrorCounter++;
    	WrLog("Error - Fail / missing parameter $Param");
    }
    exists $ScdbVerRes{$G_EnvParams{ScdbVersion}}  or $G_ErrorCounter++,WrLog("Err - Unknown ScdbVersion $G_EnvParams{ScdbVersion}") ;
    exists $ScdbPvvmRes{$G_EnvParams{PvvmType}}    or $G_ErrorCounter++,WrLog("Err - Unknown Pvvm $G_EnvParams{PvvmType}");
    exists $InstallType{$G_EnvParams{InstallType}} or $G_ErrorCounter++,WrLog("Err - Unknown Install Type $G_EnvParams{InstallType}");
    push(@Message,"Info - The Following System Exist at SCDB:");
    foreach my $SysName ( @{$G_EnvParams{SystemNames}} )
    {
    	push(@Message,"\t* $SysName");
    }
    WrLog(@Message,'-' x 60,"");
	my %ExtraParams;
	my %GrpList;
	foreach my $UnitRec ( values (%UnitListRec) )
	{
		exists $GrpList{$UnitRec->{Group}} and next;
		my $UnitType=$UnitRec->{Group};
		$GrpList{$UnitType}=1;
		my $Xpath="//Object[objectName=\"$UnitType\"]/\@display";
		$ExtraParams{$Xpath}=$InstallType{$G_EnvParams{InstallType}};
		$Xpath="//Object[objectName=\"$UnitType\"]/\@inventoryMask";
		$ExtraParams{$Xpath}="N/A";
	}
	while ( my ($Xpath,$XVal) = each(%{$ScdbPvvmRes{$G_EnvParams{PvvmType}}->[0]}) )
	{
		$ExtraParams{$Xpath}=$XVal;
	}
    #######     Assign  The Result Factory   ######
 
    $Result{ScdbMerge}=$ScdbVerRes{$G_EnvParams{ScdbVersion}}[0];
    $Result{buildTemplate}=$ScdbVerRes{$G_EnvParams{ScdbVersion}}[1];
	my %TemplateRecList=ReadMapFile($G_CLIParams{Map},$G_EnvParams{ScdbType},$G_EnvParams{PvvmType});
    $Result{TemplateFile}=\%TemplateRecList;
	exists $G_CLIParams{D} and WrLog(sprintf("Debug - Avialable Services %s",join(",",keys(%{$Result{TemplateFile}}))));
    ## $Result{AddApp}=$ScdbPvvmRes{$G_EnvParams{PvvmType}}[0];
    $Result{AddUnits}=$ScdbVerRes{$G_EnvParams{ScdbVersion}}[2];
	$Result{Distribute}=$ScdbVerRes{$G_EnvParams{ScdbVersion}}->[3];
    $Result{MergeFile}="/tmp/Template_scdb_system.xml";
    $Result{Generate}=\&ScdbGenerate;
    $Result{Validate}=\&ValidateSCDB; 
	$Result{PvvmType}=$G_EnvParams{PvvmType};
	$Result{InstallType}=$G_EnvParams{InstallType};
	$Result{Attributs}=\%ExtraParams; 
	$G_ErrorCounter and WrLog("Error - Fail to Init Script. one of the initial parameters is wrong or not supported.") , return;
    
    ####  SCDb Settings     ###
    my @PostInstallOperation=($ScdbPvvmRes{$G_EnvParams{PvvmType}}[1]);
    $Result{PostInstall}=\@PostInstallOperation;
    return %Result;
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
my ($ScdbBackup,%UnitList,%SCDBObj);
#### Call Factory Builder (Check scdb version and Type (distribute or single) and PVVM Type (IS4/IS3)###
$G_ScdbFile=GetSCDBPath();
%UnitList=ParseUnitGroup($G_CLIParams{UnitGroup});
keys(%UnitList) or WrLog("Warning - Empty Unit List. This may be cause configuration Error");
if ( exists $G_CLIParams{D} )
{
	while ( my ($HKey,$HVal) = each(%UnitList) )
	{
		WrLog("Debug - $HKey -> $HVal");
	}
}
%SCDBObj=ScdbFactory(%UnitList);
exists $SCDBObj{InstallType} or $G_ErrorCounter++;
$G_ErrorCounter and EndProg(1,"Fatal - Fail to Determine which installation Type this machine Requiers");
WrLog("Info - This is $SCDBObj{InstallType} installation add units to scdb");
## Build Unit List using UnitsBackup.Oct  and unitList.txt  ##

$ScdbBackup=BackupFile($G_ScdbFile) or EndProg(1,"Fatal - Fail to Backup scdb");
 push(@G_RollBackList,$ScdbBackup);
 foreach my $ServiceName ( split(/,/,$G_CLIParams{Service} ) )
 {
	## %SCDBObj=ScdbFactory($ServiceName);
	unless ( exists $SCDBObj{TemplateFile}->{$ServiceName} )
	{
		RollBack() ;
		WrLog("Error - \"$ServiceName\" is not supported for scdb configuration. available services:",
			   sprintf("\t- %s",join(",",keys(%{$SCDBObj{TemplateFile}}))));
		EndProg(1,"Fatal - Skip SCDB update due to Errors during merge process see log $G_CLIParams{LogFile}");
	}
	WrLog("Info - Start Merge Procedure using template $SCDBObj{TemplateFile}->{$ServiceName}");
	if ( $SCDBObj{buildTemplate}->("$G_CLIParams{TemplateFolder}/$SCDBObj{TemplateFile}->{$ServiceName}",$SCDBObj{MergeFile},$G_CLIParams{SysName},$SCDBObj{Attributs}) )
	{
		WrLog("Error - Failed to Build Template File. Start Rollback scdb");
		RollBack() and WrLog("Error - FAIL TO RESTORE SOME OF FILES - Pleas check the Log and restore it Manually ...");
		EndProg(1,"Fatal - Skip SCDB update due to Errors see Log $G_CLIParams{LogFile}");
	}
	if (  $SCDBObj{ScdbMerge}->($SCDBObj{MergeFile}) )
	{
		WrLog("Error - Failed to Merge scdb File. Start Rollback scdb");
		RollBack() and WrLog("Error - FAIL TO RESTORE SOME OF FILES - Pleas check the Log and restore it Manually ...");
		EndProg(1,"Fatal - Skip SCDB update due to Errors see Log $G_CLIParams{LogFile}");
	}
 }
WrLog("Info - Add units to scdb ....");
$G_ErrorCounter += $SCDBObj{AddUnits}->(\%UnitList,$SCDBObj{Attributs});
####  Check Result .....
if ( $G_ErrorCounter or $SCDBObj{Validate}->() )
{
   WrLog("Error - Fail to Update scdb. Roll Back to old SCDB");
   RollBack() and WrLog("Error - FAIL TO RESTORE SOME OF FILES - Pleas check the Log and restore it Manually ...");
   WrLog(@G_RollBackList);
   EndProg(1,"Fatal - SCDB Update failed see Log $G_CLIParams{LogFile}");
}
## Generate + Distribute ####
WrLog("Info - Start Generating Unit group + distribute ...");
$G_ErrorCounter += $SCDBObj{Generate}->($SCDBObj{Distribute});
###  SCDB Post Install ####  Add Units to /etc/hosts
WrLog("Info - Running Post instal (if it is nedded)...");
my $FuncList=$SCDBObj{PostInstall};
foreach my $RunFunc (@$FuncList)
{
   $G_ErrorCounter += $RunFunc->();
}
my $ErrMessage= $G_ErrorCounter ? "Finish with ERRORS see Log File $G_CLIParams{LogFile}" :
		"Finish Successfully :-)";
EndProg($G_ErrorCounter,$ErrMessage);