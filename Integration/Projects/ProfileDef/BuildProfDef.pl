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
use Spreadsheet::ParseExcel;
use XML::LibXML ;

#########################################################
#  Global variables
#########################################################

my $G_ErrorCounter=0;
my %G_CLIParams=(  LogFile  => "-" );
my @G_FileHandle=();

sub usage
{
    print "$0 -Excel ExcelFile -Target ProfileDefFile [-Sheets WorkShhet List] [-LogFile FileName]\n";
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
		PrnTitle(sprintf("Start $0 at %02d/%02d/%4d",$DArr[3],$DArr[4]+1,$DArr[5]+1900));
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

sub MkChiled #XmlObj,Xpath  ==> return the new chiled
{
	my $XmlNode=shift;
	my $Xpath=shift;
	## WrLog("Debug - MkChiled($XmlNode,$Xpath)");
	unless ( $Xpath =~ /^\./ )
	{
		$Xpath = $Xpath =~ /^\// ? ".$Xpath" : "./$Xpath" ;
	}
	## WrLog("Dbug - Xpath Before Use:\"$Xpath\"");
	my @Nodes = $XmlNode->findnodes($Xpath) ;
	@Nodes and return $Nodes[0];
	### The Chiled do not exists Create it !
	my $NodeName= $Xpath =~ s/\/([^\/]+?)$// ? $1 : $Xpath ;
	my $TmpNode = $Xpath =~ /(\.|\/)$/ ? $XmlNode : MkChiled($XmlNode,$Xpath) ;
	return ref($TmpNode) ? $TmpNode->appendChild(XML::LibXML::Element->new($NodeName)) : undef ;
}

sub UpdateProfile #$FileName,\%ParamsList
{
	my $FileName=shift;
	my $ParamList=shift;
	my $XMLObj= -e $FileName ? XML::LibXML->new()->parse_file($FileName) : XML::LibXML->new()->parse_string(
				qq(<Provisioning><ProfileDefinition Name="$FileName" Version="1.0.0.0"><Entities><Entity><Name>Unknown</Name><DsvEntityName>New</DsvEntityName><Fields/></Entity></Entities></ProfileDefinition></Provisioning>)  );
	$XMLObj or WrLog("Error - Fail to Parse/Create $FileName"), return;	

    ####    TODO  - Add Field map 
	my %FieldMap =( "DBType"		=> "DbData/DbType" ,
				   "Len"		=> "DbData/DbLength" ,
				   "DBName"		=> "DbName"	,
				   ## "Name"		=> "DsvName" ,
				   "CompType"	=> "XsdValidation/Type" ,
				   "IsNill"		=> "XsdValidation/Nillable" ,
				   "EnumList"	=> "XsdValidation/Lov/Value" ,
				   "Diplay"		=> "DisplayName" ,
				   "MinVal"		=> "XsdValidation/MinVal" ,
				   "MaxVal"		=> "XsdValidation/MaxVal" ,
				   "MultiVal"	=> "MultiValueElementName" ,
				   "WSAsubgroup" => "SubGroupName" );
				   
	my %BehavMap = ( "SysDefault"	=> "SubscriberBehavioralInfo/ResolvedLevels/SystemDefaults/DefaultValue" ,
					 "SysNill"		=> "SubscriberBehavioralInfo/ResolvedLevels/SystemDefaults/XsdValidation/Nillable" ,
					 "Service"		=> "SubscriberBehavioralInfo/ServiceName" ,
					 "SubBehave"		=> ["SubscriberBehavioralInfo/ResolvedLevels/ServiceLevel","SubscriberBehavioralInfo/ResolvedLevels/DomainDefaults"] ) ;



	
	my @Collects=$XMLObj->findnodes("//Collections/Collection/CollectionElement/Fields/Field");
	foreach my $CollEntity (@Collects)
	{
		my $ParamName=$CollEntity->findvalue("./DsvName");
		unless ( exists $ParamList->{$ParamName} )
		{
			WrLog("Warning - Collection Parameter \"$ParamName\" exists at $FileName but NOT exists at Excel File");
			next;
		}
		my $TempNode=$CollEntity->appendChild(XML::LibXML::Element->new("DbData"));
		exists $ParamList->{$ParamName}->{DBType} and $TempNode->appendTextChild("DbType",$ParamList->{$ParamName}->{DBType});
		exists $ParamList->{$ParamName}->{Len} and $TempNode->appendTextChild("DbLength" ,$ParamList->{$ParamName}->{Len}) ;
		my @Nodes=$CollEntity->findnodes(".//dbName");
		my $DBNode= @Nodes ? $Nodes[0] : $CollEntity->appendChild(XML::LibXML::Element->new("dbName"));
		$DBNode->setData($ParamList->{$ParamName}->{DBName});
		exists $ParamList->{$ParamName}->{SysDefault} or next;
		@Nodes=$CollEntity->findnodes(".//SystemDefaults");
		unless ( @Nodes )
		{
			@Nodes=$CollEntity->findnodes(".//ResolvedLevels");
			unless (@Nodes)
			{
				@Nodes=$CollEntity->findnodes(".//SubscriberBehavioralInfo");
				@Nodes or @Nodes=( $CollEntity->appendChild(XML::LibXML::Element->new("SubscriberBehavioralInfo")) );
				@Nodes = ( $Nodes[0]->appendChild(XML::LibXML::Element->new("ResolvedLevels")) );
			}
			@Nodes = ( $Nodes[0]->appendChild(XML::LibXML::Element->new("SystemDefaults")) );
		}
		foreach my $DefVal ( @{$ParamList->{$ParamName}->{SysDefault}} )
		{
			$CollEntity->findnodes(qq(.//SystemDefaults[DefaultValue="$DefVal"])) and next
			$Nodes[0]->appendTextChild("DefaultValue",$DefVal);
		}
		delete($ParamList->{$ParamName});
	}
	
	###  Go Over all Parameters  ###
	my @FieldsNode=$XMLObj->findnodes("//Entities/Entity/Fields");
	my $FieldRoot=$FieldsNode[0];
	while ( my ($ParamName,$PRec) = each(%{$ParamList}) )
	{
		@FieldsNode=$FieldRoot->findnodes(qq(.//Field[DsvName="$ParamName"]));
		if ( exists $PRec->{Delete} )
		{
			WrLog("Info - $ParamName should be delete ...");
			@FieldsNode or next;
			$FieldRoot->removeChild($FieldsNode[0]);
		}
		
		unless ( @FieldsNode )
		{
			WrLog("Info - Add New Parameter \"$ParamName\"");
			@FieldsNode=( $FieldRoot->appendChild(XML::LibXML::Element->new("Field")) );
			$FieldsNode[0]->appendTextChild("Name",$ParamName);
			exists $PRec->{Description} and $FieldsNode[0]->appendTextChild("Description",$ParamName);
			$FieldsNode[0]->appendTextChild("DsvName",$ParamName);
		}
		my ($ActNode,$OldNode);
		my %FullMap= exists $PRec->{SubBehave} ? (%FieldMap,%BehavMap) : %FieldMap ;
		while ( my ($PIndex,$PPath) = each (%FullMap) )
		{
			exists $PRec->{$PIndex} or WrLog("Warning - Missing Excel Parameter \"$PIndex\"") , next;
			if ( ref ( $PPath ) )
			{
				foreach my $MultiPath (@$PPath) 
				{
					MkChiled($FieldsNode[0],$MultiPath);
				}
				next ;
			}
			if ( ref($PRec->{$PIndex}) )
			{  ## List of Values  ####
				WrLog("Debug - Start Defining Enum for $ParamName ...");
				$PPath =~ /(.+)\/([^\/]+?)$/ or EndProg(1,"Error - Fail to Find List of Element Xpath for $PIndex ...");
				$OldNode=$1;
				$ActNode=$2;
				my $RootNode=MkChiled($FieldsNode[0],$OldNode);
				foreach my $Iter (@{$PRec->{$PIndex}})
				{
					WrLog("Debug - Working on val $Iter ....");
					my $XpathStr=sprintf(".//$OldNode\[$ActNode=\"$Iter\"\]/$ActNode");
					$FieldsNode[0]->findnodes($XpathStr) and next;
					$RootNode->appendTextChild($ActNode,$Iter);
				}
			} else
			{
				my $NodeName= $PPath =~ /\/([^\/]+?)$/ ? $1 : $PPath ;
				$ActNode=XML::LibXML::Element->new($NodeName);
				$ActNode->appendText($PRec->{$PIndex});
				$OldNode=MkChiled($FieldsNode[0],$PPath);
				$OldNode->parentNode->replaceChild($ActNode, $OldNode);
			}
		}
	}
	###   Save The New File ....  ###
	my $TmpStr=$XMLObj->toString;
	chomp($TmpStr);
	$TmpStr =~ s/>\s+</></g ;
	$XMLObj=XML::LibXML->new()->parse_string($TmpStr);
	if ( $XMLObj )
	{
		-e $FileName  and $TmpStr=BackupFile($FileName);
		$TmpStr and $XMLObj->toFile($FileName,1) and return 0;
	}
	return 1;
}

sub CheckNill
{
	my $CellVal= shift  || "false";
	$CellVal =~ /(True)|(False)/i and return  $CellVal;
	WrLog("Debug - IsNilleble value too complicated for me \"$CellVal\"");
	return ;
}

sub CleanSpace
{
	my $Result=shift;
	chomp $Result ;
	$Result =~ s/^\s+// ;
	$Result =~ s/\s+$// ;
	return $Result ;
}

sub SetUpper
{
	my $Result=shift;
	chomp $Result ;
	$Result =~ s/^\s+// ;
	$Result =~ s/\s+$// ;
	return uc($Result) ;
}

sub setBehave
{
	my $Result=shift;
	return $Result =~/Y/i ? "True" : undef ;
}

sub setCompType
{
	my $CType=shift;
	my %MapType = ( string			=> "xs:string" ,
					integer			=> "xs:integer" ,
					positiveinteger	=> "xs:positiveInteger" ,
					nonnegativeinteger => "xs:nonNegativeInteger" ,
					boolean			=> "xs:boolean" ,
					emailaddresstype => "compas:EmailAddressType" ,
					hourtimetype	=> "compas:HourTimeType" ,
					timetype		=> "xs:date" ,
					securedstring	=> "compas:SecuredString" ,
					telephonenumtype => "compas:TelephoneNumType" ) ;
	my $IndexStr=lc(CleanSpace($CType));
	exists $MapType{$IndexStr} and return $MapType{$IndexStr};
	WrLog("Error - Unknown Compas type \"$CType\"");
	return ;
}

sub readExcel ## $ExcelFile , @Worksheets
{
	my $ExcelFile=shift;
	my @WorkSheets=@_;
	my %Result;
					# $attr_col,$name_col,$type_col,$len_col,$nill_col,$sysdef_col
	my %ColLocation = ( IndexName					=>  ["Name","DBName","DBType","CompType","Len","IsNill","SysDefault","Service","Description","SubBehave","Valid","WSAsubgroup","Display"] ,
						"IS4 Subscriber"			=>  [ 1    , 2      , 4      , 5        ,11   , 12      , -1         ,-1      , -1 ] ,
						"Subscriber-related tables"	=>  [ 0    , 1      , 3      , 4        ,10   ,11       , -1         , -1     ,  -1] ,
						"VVM Subscriber"			=>  [ 0    , 1      , 3      , 4        ,9    ,11       , -1         , -1     ,  -1] ,
						"VM2MMS Subscriber"			=>  [ 0    , 1      , 3      , 5        , 4   , 13      , 11         , 10     , 2           ,  9		,6     ,15			,16] ,
						"VW(VM2Text) Subscriber"	=>	[ 0    , 1      , 3      , 5        , 4   , 13      , 11         , 10     , 2           ,  9		,6     ,15			,16] ,
						"WHC-NFM Subscriber"		=>	[ 0    , 1      , 3      , 5        , 4   , 13      , 11         , 10     , 2           ,  9		,6     ,15			,16] ,
						"Nfm Black-White List"		=>	[ 0    , 1      , 3      , 5        , 4   , 13      , 11         , 10     , 2           ,  9		,6     ,15			,16] ,
						"Smart Call"				=>	[ 0    , 1      , 3      , 5        , 4   , 13      , 11         , 10     , 2           ,  9		,6     ,15			,16] ,
						"Call Screening"			=>  [ 0    , 1      , 3      , 5        , 4   , 13      , 11         , 10     , 2           ,  9		,6     ,15			,16] ,
						"InSight related MIPS"		=>	[0,1,3,4,13,11] );
						
	my %CollEval = ( IsNill		=> \&CheckNill ,
					 Name		=> \&CleanSpace ,
					 DBName		=> \&SetUpper ,
					 DBType		=> \&CleanSpace ,
					 Service	=> \&CleanSpace  ,
					 SubBehave	=> \&setBehave ,
					 CompType	=> \&setCompType,
					 WSAsubgroup => \&CleanSpace );

	my $ExcelObj=Spreadsheet::ParseExcel->new()->parse($ExcelFile) ;
	$ExcelObj or WrLog("Error - fail to Parse Excel file $ExcelFile ...");
	
	foreach my $worksheet (@WorkSheets) 
	{
		exists $ColLocation{$worksheet} or WrLog("Error - Worksheet $worksheet is not supported yet ..."), return;
		my $ExcelPage=$ExcelObj->Worksheet($worksheet);
		my ( $row_min, $row_max ) = $ExcelPage->row_range();
        my ( $col_min, $col_max ) = $ExcelPage->col_range();
		if ( $col_max - $col_min < 5 )
		{
			WrLog("Warning - Worksheet \"$worksheet\" do not have enough columns ($col_max). skip this worksheet.");
			next;
		}
		
		## WrLog("Debug - Start Col $col_min ... $col_max");
		
		if ( $row_max - $row_min < 2 )
		{
			WrLog("Warning - looks like Worksheet \"$worksheet\" is empty. skip this worksheet.");
			next;
		}
		
		###  Start Parse  ####
		my $TableName;
		foreach my $RowIndx ( $row_min .. $row_max )
		{
			my $SingleCell=$ExcelPage->get_cell($RowIndx,$ColLocation{$worksheet}->[0]);
			$SingleCell or WrLog("Debug - cell ($RowIndx),($ColLocation{$worksheet}->[0]) is undefined"), next;
			my $AttName=$SingleCell->Value();
			$AttName or WrLog("Info - Row $RowIndx is empty at Worksheet $worksheet");
			$AttName =~ /Attribute\s+Name/i and WrLog("Info - Title of $worksheet locate at Row $RowIndx") , next;
			if ( $AttName =~ /(\S+)\s+table/i )
			{
				$TableName=uc($1);
				WrLog("Debug - Table Name is $TableName ...");
				next;
			}
			my %FRec= ( Table	=>  $TableName );
			$AttName=$CollEval{"Name"}->($AttName);
			my $CFormat=$SingleCell->get_format();
			my $Cfont=$CFormat->{Font};
			
			## WrLog(sprintf("Debug - Cel Format ($RowIndx) : Style %s , Font %s ,strickout %s",$CFormat->{Style},$Cfont->{Name},$Cfont->{Strikeout}));
			$Result{$AttName}=\%FRec;
			$Cfont->{Strikeout} and $FRec{Delete}="True" , next;
			#WrLog(sprintf("Debug - Cel Format ($RowIndx) : Style %s , Font %s ,strickout %s (%d)",$CFormat->{Style},$Cfont->{Name},$Cfont->{Strikeout},$Cfont->{Strikeout}));
			for ( my $Colmn=1 ; $Colmn < @{$ColLocation{$worksheet}} ; $Colmn++ )
			{
				$ColLocation{$worksheet}->[$Colmn] < 0 and next ;
				my $CollName=$ColLocation{IndexName}->[$Colmn];
				my $ColmnLocation=$ColLocation{$worksheet}->[$Colmn] ;
				$ColmnLocation < 0 and next ;
				$SingleCell = $ExcelPage->get_cell($RowIndx,$ColmnLocation);
				my $CollVal = defined $SingleCell ? $SingleCell->unformatted() : undef ;
				exists $CollEval{$CollName} and  $CollVal=$CollEval{$CollName}->($CollVal) ;
				defined $CollVal or WrLog("Warning - empty Cell for $CollName at worksheet $worksheet Row $RowIndx column $ColLocation{$worksheet}->[$Colmn]"), next;
				$FRec{$CollName}=$CollVal;
			}
			### Fix Some Changes ####
			$FRec{DBName} = $TableName . "." . $FRec{DBName};
			uc($TableName) eq "SUBSCRIBERS" or $FRec{MultiVal}="Value";
			if ( exists $FRec{Valid} )
			{
				if ( $FRec{CompType} =~ /string/i )
				{
					my @TmpList=split(/,/,$FRec{Valid});
					if ( @TmpList > 1 )
					{
						$FRec{EnumList}=[];
						foreach my $StrVal (@TmpList)
						{
							push(@{$FRec{EnumList}},CleanSpace($StrVal));
						}
					}
				} elsif ( $FRec{CompType} =~ /int/i )
				{
					my @TmpList=split(/[,\-]/,$FRec{Valid});
					$FRec{MinVal}=CleanSpace($TmpList[0]);
					$FRec{MaxVal}=CleanSpace($TmpList[-1]);
				}
			}
			exists $FRec{SubBehave} or next;
			if ( $FRec{DBType} =~ /Number/i and $FRec{SysDefault} =~ /\D/ )
			{
				$FRec{SysDefault} =~ /false/i and $FRec{SysDefault}=0;
				$FRec{SysDefault} =~ /true/i  and $FRec{SysDefault}=1;
				$FRec{SysDefault} =~ /\D/ and WrLog("Warning - $AttName has non Number type for System Default ! at Row Number $RowIndx");
			}
			$FRec{IsNill}="true";
			$FRec{SysNill}="false";
		}
	}
	return %Result;
}

sub getWorksheetList
{
	my %FileMap = ( "ProfileDefinitions_InSight"	=> [] ,
					"ProfileDefinitions_WHC"		=> ["WHC-NFM Subscriber"] ,
					"ProfileDefinitions_CallScreening" => ["Call Screening"] ,
					"ProfileDefinitions_SmartCall"	=> ["Smart Call"],
					"ProfileDefinitions_WHC-BWList"	=> ["Nfm Black-White List"] ,
					"ProfileDefinitions_VVM"		=> [] ,
					"ProfileDefinitions_MMG"		=> [] );
	exists $G_CLIParams{Sheets} and return split(/,/,$G_CLIParams{Sheets});
	
    my $MapName=$G_CLIParams{Target};
	## $MapName =~ s/.xml//i ;
	$MapName =~ /([^\/\\]+)\.xml$/ and $MapName=$1;
	unless ( exists $FileMap{$MapName} )
	{
		WrLog("Error - I Can not determine which workshheet to use for \"$G_CLIParams{Target}\"");
		$G_ErrorCounter++;
		return ;
	}
	return @{$FileMap{$MapName}} ;
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

my %ParamsList=readExcel($G_CLIParams{Excel},getWorksheetList());

$G_ErrorCounter += UpdateProfile($G_CLIParams{Target},\%ParamsList);

my $ErrMessage= $G_ErrorCounter ? "Finish with ERRORS see Log File $G_CLIParams{LogFile}" :
		"Finish Successfully :-)";
EndProg($G_ErrorCounter,$ErrMessage);