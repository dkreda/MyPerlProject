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
use mdbReader;
use XML::LibXML ;
#########################################################
#  Global variables
#########################################################

my $G_ErrorCounter=0;
my %G_CLIParams=(  LogFile  => "-" ,
		   DefaultDir => "/tmp" ,
		   SearchLevel	=> 2 ) ;
my @G_FileHandle=();

sub usage
{
    print "$0 [-LogFile FileName] -Map csvFileName -File Listofmdb fiels (or folder) [-SearchLevel number]\n";
    print "$0 -help\n";
	print "\n-Map  - Path to csv File. which Map Octopus UnitType to SCDD Unit Type.\n";
	print "-File   - List of mdb files or Directory where to find mdb files\n";
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
# Description:  convert from Hash to single Line.
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


sub getProduct   ## ($MdbObj)
##############################################################################
#
# Input:	$MdbObj
#			$MdbObj is mdb Object - Object That Handle mdb files ( it create via mdbReader::Parser )
#			This object should be already initial when calling this procedure.
#		
# Return:	%Product  - Hash table of Products the hash table cotent:
#			Key = Product Name .
#			Value =  Execution Number/order.
#
# Description: This Procedure Parse all the product of mdb file and check the Execution Order. it check dependencies
#				means if foo1 depends on foo2 foo2 Execution number will be LOWER than foo1
#
###############################################################################
{
	my $Mdbobj=shift;
	my $ProductTable=$Mdbobj->getTableByName("Products");
	my @ProList=$ProductTable->getRows("ProductName","InstallationPhaseNumber","Depends");
	my %Result;
	###Sort Products  ###
	foreach my $Row ( @ProList ) 
	{
		$Result{$$Row[0]}= (15 + $$Row[1] ) * 10 ;
		### ( $$Row[1] < 0 or $$Row[1] > 10000 ) and WrLog("","","OOOOOOOPs Execution Orde Out of Range \"$$Row[1]\"","","");
	}
	##### Check depenedenc
	my $SortFlag=1;
	while ( $SortFlag ) 
	{
		$SortFlag=0;
		foreach my $Row ( @ProList ) 
		{
			$$Row[2] or next;
			## WrLog("Debug - Product $$Row[0] has depend \"$$Row[2]\"");
			#### Find maximum depend  ####
			my $Depend=0;
			foreach my $ProdName ( split(/[,;]/,$$Row[2]) ) 
			{
				$Result{$ProdName} > $Depend and $Depend=$Result{$ProdName};
			}
			$Result{$$Row[0]} > $Depend and next ;
			$SortFlag=1;
			$Result{$$Row[0]} = $Depend + 2 ;
		}
	}
	return %Result;	
}

sub updateUnit
{
	my $MapRec=shift;
	my $UnitType=shift;
	my %Options=@_;
	if (  exists $MapRec->{$UnitType} ) 
	{
		while ( my ($OpKey,$OpVal) = each(%Options) ) 
		{
			$MapRec->{$UnitType}->{$OpKey}=$OpVal;
		}
	} else
	{
		$MapRec->{$UnitType}=\%Options;
	}
	return 0;
}

sub setUnitCAF  ### \%MapRec,$UnitType,$CompName,$CompVer,$FilePath
{
	my $MapRec=shift;
	my $UnitType=shift;
	my $CompName=shift;
	my $CompVersion=shift;
	my $FilePath=shift;
	my $UAFCompObj;
	my $UAFXmlObj;
	## my $Platform=shift;


	my $CAFXmlObj=XML::LibXML::Document->createDocument("1.0","UTF-8");
	my $Root=XML::LibXML::Element->new("SWIM");
	my $CompObj=$Root->appendChild(XML::LibXML::Element->new("Component"));
	$CompObj->setAttribute("Name","$CompName"."_$UnitType");
	$CompObj->setAttribute("Version",$CompVersion);
	$CompObj->setAttribute("Platform",$MapRec->{$UnitType}->{OPSys});
	$CAFXmlObj->setDocumentElement($Root);
	$MapRec->{$UnitType}->{CAFXml}=$CAFXmlObj;
	$MapRec->{$UnitType}->{CAFFileName}= ($FilePath ? "$FilePath/" : "") . $CompName . "_$UnitType-CAF.xml" ;
	if ( exists $MapRec->{$UnitType}->{UAFXml} ) 
	{
		$UAFXmlObj=$MapRec->{$UnitType}->{UAFXml};
		$UAFCompObj=ValidatePath($MapRec->{$UnitType}->{UAFXml},"/SWIM/UnitType/Install");
		exists $G_CLIParams{D} and  WrLog("Debug - Update UAF Obj for Unit $UnitType ($UAFCompObj)");
		
	} else 
	{
		$MapRec->{$UnitType}->{UAFFileName}= $MapRec->{$UnitType}->{GroupName} ."-UAF.xml" ;
		unless ( -e $MapRec->{$UnitType}->{UAFFileName} ) 
		{
			$UAFXmlObj=XML::LibXML::Document->createDocument("1.0","UTF-8");
			$Root=XML::LibXML::Element->new("SWIM");
			$UAFCompObj=ValidatePath($Root,"//SWIM/UnitType");
			$UAFCompObj->setAttribute("Name",$MapRec->{$UnitType}->{GroupName});
			$UAFCompObj->setAttribute("Platform",$MapRec->{$UnitType}->{OPSys});
			$UAFCompObj=ValidatePath($Root,"//SWIM/UnitType/Install");
			$UAFXmlObj->setDocumentElement($Root);
		} else
		{
			$UAFXmlObj=XML::LibXML->new()->parse_file($MapRec->{$UnitType}->{UAFFileName});
			$UAFCompObj=ValidatePath($UAFXmlObj,"//SWIM/UnitType/Install");
		}
		$MapRec->{$UnitType}->{UAFXml}=$UAFXmlObj;
		exists $G_CLIParams{D} and  WrLog("Debug - Create new UAF Obj for Unit $UnitType ($UAFCompObj)");
	}
	$UAFCompObj=$UAFCompObj->appendChild(XML::LibXML::Element->new("Component"));
	$UAFCompObj->setAttribute("Name","$CompName"."_$UnitType");
	## $UAFCompObj->appendChild(XML::LibXML::Comment->new("Added by Automatic Script setUnitCAF Fuction"));
	exists $MapRec->{$UnitType}->{VFlag} or return 0;
	$UAFCompObj=$UAFCompObj->appendChild(XML::LibXML::Element->new("OnlyOn"));
	$UAFCompObj->appendTextChild("UnitName","\{$UnitType\}");
	return 0;
}

sub ReadUnitMap
{
	my $CsvFileName=shift;
	my @CsvUnitRec=ReadFile($CsvFileName);
	my %Result;
	foreach my $Line  (@CsvUnitRec) 
	{
			####  Ignore the Title
		$Line =~ /Octopus Unit Type/ and next ;
		my @Fields=split(/,/,$Line);
		$Result{$Fields[0]}= { GroupName => $Fields[1] ,
							   Platform  => $Fields[2] };
	}
	return %Result;
}

sub setUnitsRec      #$MdbObj  , \%UnitMap(OpSys+UnitGroup)  return %Hash{UnitTypes}->(Rec) 
##############################################################################
#
# Input:	$MdbObj , \%UnitMap
#			$MdbObj is mdb Object - Object That Handle mdb files ( it create via mdbReader::Parser )
#			This object should be already initial when calling this procedure.
#			%UnitMap - Hash : Key = OctopusUnitName , Value = \%Hash ( Platform => (Linux or SunOS) ,
#																	   GroupName => The Name of Group as exists at UnitGroup.xml).
#		
# Return:	%UnitRec  - Hash table cotent:
#			Key = Octopus Unit Type ( as appears at View Edit Unit List at Octopus )
#			Value =  Record ( %Hash : ( OPSys -> Linux or SunOS, UAFXml -> XMlObj , {$CompName => ExecOrder } ... more
#								
#
# Description: 
#
###############################################################################
{
	my $MdbObj=shift;
	my $UnitMap=shift;
	my @RowList;
	my %Result;
	my $Err=0;
	my $Component=$MdbObj->{FileName};
	my $CompFolder;
	$Component =~ s/^(.+)[\/\\]// and $CompFolder=$1;;
	$Component =~ s/\.mdb//i ;
	exists $G_CLIParams{D} and WrLog("Debug - about to Read General Table");
	my $GenTable=$MdbObj->getTableByName("General");
	my $CompVer="Unknown Version";
	if ( $GenTable ) 
	{
		exists $G_CLIParams{D} and WrLog("Debug - Paesing Version Column");
		@RowList=$GenTable->getRows("Version");
		exists $G_CLIParams{D} and WrLog("Debug - General Table Result",@{$RowList[0]});
		$RowList[0]->[0] and $CompVer=$RowList[0]->[0];
	}
	
	my %Products=getProduct($MdbObj);
	my $UnitProTable=$MdbObj->getTableByName("ProductInUnit");
	@RowList=$UnitProTable->getRows("ProductName","UnitType");
	## my %Options;
	foreach my $Field (@RowList) 
	{
		unless ( exists $Products{$Field->[0]} ) 
		{
			WrLog("Error - Product \"$Field->[0]\" exists at table ProductInUnit But missing at table Products at file $MdbObj->{FileName}");
			## $Err++;
			$G_ErrorCounter++;
			next;
		}
		unless ( exists $UnitMap->{$Field->[1]} ) 
		{
			WrLog("Error - missing UnitType Mapping \"$Field->[1]\" at file $G_CLIParams{Map} This UnitType will be ignored");
			$G_ErrorCounter++;
			## $Err++;
			next ;
		}
		## WrLog("Debug UnitMap:",$UnitMap->{$Field->[1]});
		$Result{$Field->[1]}->{$Field->[0]}=$Products{$Field->[0]};
		exists $Result{$Field->[1]}->{OPSys} and next;
		my %Options = ( OPSys		=> $UnitMap->{$Field->[1]}->{Platform} ,
						$Field->[0] => $Products{$Field->[0]} ,
						GroupName	=> $UnitMap->{$Field->[1]}->{GroupName} );
		$Err += updateUnit(\%Result,$Field->[1],%Options);
		$Err += setUnitCAF(\%Result,$Field->[1],$Component,$CompVer,$CompFolder);
		exists $Result{$Field->[1]}->{VirtualParams} and delete $Result{$Field->[1]}->{VirtualParams} ;
		exists $G_CLIParams{D} and WrLog("Debug - Create Unit Record for Unit Type $Field->[1]");
	}
	########    Setup Exeution Order for each UnitType   #####
	while ( my ($UnitType,$Rec) = each(%Result) ) 
	{
		### Calculate the most high execution group ...
		my $Max=-1000;
		my $SerachVal=$Component ."_$UnitType";
		my @NList=$Rec->{UAFXml}->findnodes("//UnitType/Install/Component[\@Name=\"$SerachVal\"]");
		@NList or WrLog("Warning - $UnitType has no component $Component at Uaf file ($SerachVal)"),next;
		my $CompNode=$NList[0];
		while ( my ($CompName,$PhassNum) = each(%$Rec) ) 
		{
			$PhassNum =~ /^[\-\d]+$/ or next;
			$CompNode->appendChild(XML::LibXML::Comment->new("This Component has Product Name $CompName with ExecutionPhass $PhassNum"));
			$Max < $PhassNum and $Max=$PhassNum;
		}
		$CompNode->setAttribute("ExecutionOrder",$Max);
	}
	$Err and $G_ErrorCounter++;
	return %Result;
}

sub AddBatch ## \@Row , $Exeution Order
{ 
	my $Row=shift;
	my $ExecOrd=shift;
    my $Target=$Row->[4] ;
	unless ( $Target ) 
	{
		my $TmpFile = $Row->[3];
		$TmpFile =~ s/^.*[\/\\]// ;
		$Target="$G_CLIParams{DefaultDir}/$TmpFile";
	}
	### WrLog("Debug - Create Execute Node ...");
	my $Result=XML::LibXML::Element->new("Execute");
	## WrLog("Debug - Set Attribute  ...");
	$Result->setAttribute("ExecutionOrder",$ExecOrd);
	$Row->[7] and  $Result->setAttribute("Timeout",$Row->[7]);
	## WrLog("Debug - Append Text Node ... \"$Target $Row->[5]\"");
	my $RpmOp= $Row->[5] =~ /-[iU]/ ? $Row->[5] : "-iv $Row->[5]";
	$Result->appendTextChild("Command",$Target =~ /\.rpm$/i ? "rpm $RpmOp $Target" : "$Target $Row->[5]");
	return $Result;
}

sub AddCopy ## \@Row , $Exeution Order
{
	my $Row=shift;
	my $ExecOrd=shift;
	my $Result=XML::LibXML::Element->new("Copy");
	$Result->setAttribute("ExecutionOrder",$ExecOrd);
	my $Source=$Row->[3];
	$Source =~ s/\\/\//g;
	## my $Target=$Row->[4];
	$Result->appendTextChild("Source",$Source);
    $Result->appendTextChild("Target",$Row->[4]);
	return $Result;
}

sub CopyExec
{
	my $Row=shift;
	my $ExecOrd=shift;
	$Row->[3] or return undef;
	my $Target=$Row->[4] ;
	unless ( $Target ) 
	{
		my $TmpFile = $Row->[3];
		$TmpFile =~ s/^.*[\/\\]// ;
		$Target="$G_CLIParams{DefaultDir}/$TmpFile";
		$Target =~ /\*/ and $Target =~ s/[^\\\/]+$//;
	}
	my $Source=$Row->[3];
	$Source =~ s/\\/\//g;
	my $Result=XML::LibXML::Element->new("Copy");
	$Result->setAttribute("ExecutionOrder",$ExecOrd);
	$Result->setAttribute("ChmodFlags","+x");
	$Result->appendTextChild("Source",$Source);
    $Result->appendTextChild("Target",$Target);
	return $Result;
}

sub CreateVirtualUnit # UnitName,Product,\%UnitsRec,CAFFileLocation
{
	my $VUnitName=shift;
	my $ProductName=shift;
	my $UnitsRec=shift;
	my $CAFLocation=shift;
	my ($CName,$CVer,$UnitTypeRec,$Err);
	my %Toptions= ( GroupName => "Virtual" ,
					OPSys	  => "Linux"  ,
					VFlag	  => $ProductName );
	## foreach $UnitTypeRec ( values(%$UnitsRec) ) 
	while ( ($Err,$UnitTypeRec) = each (%$UnitsRec) ) 
	{
		exists $UnitTypeRec->{$ProductName} and last;
	}

	####    Find some Component Variable using the UnitTypeRec ...
	exists $UnitTypeRec->{$ProductName} or WrLog("Error - \"$ProductName\" should not run on any Unit $VUnitName should be ignored"),return 1;
	my @List=$UnitTypeRec->{CAFXml}->documentElement()->findnodes("//Component");
	$CName=$List[0]->getAttribute("Name");
	$CVer=$List[0]->getAttribute("Version");
	###  Remove the Unit Type name from componete Name
	$CName =~ /_([^_]+)$/ and exists $UnitsRec->{$1} and $CName =~ s/_[^_]+$// ;
	### Update all the relevant Product of virtual unit execution Oreder
	while ( my ($CompName,$ExcOrder) = each(%$UnitTypeRec) ) 
	{
		$CompName =~ /(CAF|VirtualParams|Opsys)/i and next;
		$Toptions{$CompName}=$ExcOrder;
	}
	while ( $CAFLocation and ! -d $CAFLocation ) 
	{
		$CAFLocation =~ s/[\/\\][^\/\\]+$// and next;
		WrLog("Warning - CAF File location \"$CAFLocation\" is not legal using local directory");
		$CAFLocation=".";
	}
	$Err = updateUnit($UnitsRec,$VUnitName,%Toptions);
	$Err += setUnitCAF($UnitsRec,$VUnitName,$CName,$CVer,$CAFLocation);
	return $Err;
}

sub AddInstalltion  ####  ($MdbObj,\%UnitsRec);
{
	my $MdbObj = shift ;
	# my $CAFObj = shift ;
	my $UnitsRec = shift;
	my %Operation = ( Copy	=> [\&AddCopy,0] ,
			  Batch	=> [\&AddBatch,3,\&CopyExec,0] ,
			  PostBatch => [\&AddBatch,5,\&CopyExec,3] ,
			  PreBatch => [\&AddBatch,-3,\&CopyExec,-5] );
	my $Err=0;
	my %InstallTree;
	#### Read Instal Table
	exists $G_CLIParams{D} and  WrLog("Debug - Parsing install Table at file $MdbObj->{FileName}");
	my $InstTable=$MdbObj->getTableByName("Install");
	my @CmdList=$InstTable->getRows("OperationType","Platform","ProductName","Param1","Param2","Param3","ExecutionOrder","PauseAfter","UnitTypeFilter","InstallSerial");
	exists $G_CLIParams{D} and WrLog(sprintf("Debug - Found out at table install %d relevant rows",$#CmdList+1));

	while ( my ($UnitName,$UnitRec1) = each(%$UnitsRec)) 
	{
		exists $G_CLIParams{D} and WrLog("Debug - AddInstalltion: initiat Unit \"$UnitName\" - Xml Obj: $UnitRec1:",%$UnitRec1);
		$InstallTree{$UnitName}=ValidatePath($UnitRec1->{CAFXml}->documentElement(),"//Component/Install");
		ref($InstallTree{$UnitName}) and next;
		WrLog("Error - Fail to create Install Section at file $UnitRec1->{CAFObj}->{FileName}");
		$Err++;
		delete $InstallTree{$UnitName};
	}

	foreach my $Row (@CmdList) 
	{
		exists $G_CLIParams{D} and WrLog("Debug Row Values:",@$Row);
		$Row->[1] =~ /Linux/i or next;
		unless ( exists $Operation{$Row->[0]} ) 
		{
			WrLog("Error - Unknown operation \"$Row->[0]\" at LineOrder $Row->[-1]");
			$Err++;
			next;
		}
		### Check ProductName !!!!  ###
		## WrLog("Debug - Start Analayze $Row->[0] at product $Row->[2]");

		my @UnitsList=$Row->[8] ? split(/[,;]/,$Row->[8]) : keys(%InstallTree) ;

		foreach my $UnitType ( @UnitsList ) 
		{
			### Check if the product is relvalt to the Unit type ...###
			### Validate that UnitType is not a parameter ###
			##WrLog("Debug - Exec For Unit \"$UnitType\"");
			if ( $UnitType =~ s/\{([^\}]+?)\}// ) 
			{
				$UnitType=$1;
				$UnitType =~ s/\s//g ;
				unless ( exists $UnitsRec->{$UnitType} ) 
				{
					$Err += CreateVirtualUnit($UnitType,$Row->[2],$UnitsRec,$MdbObj->{FileName});
				}
				$InstallTree{$UnitType}=ValidatePath($UnitsRec->{$UnitType}->{CAFXml}->documentElement(),"//Component/Install");
			} elsif ( ! exists $UnitsRec->{$UnitType} or exists $UnitsRec->{$UnitType}->{VFlag} ) 
			{
				###### Skip Unit Type that R used for UnitType Filter ###
				next;
			}


			exists $UnitsRec->{$UnitType} or next ;
			exists $UnitsRec->{$UnitType}->{$Row->[2]} or next ;


			#### Create Relevant Node   ####
			my @ExecList=@{$Operation{$Row->[0]}};
			while ( @ExecList ) 
			{
				my $Func=shift(@ExecList);
				my $ExecOrd=shift(@ExecList);
				$ExecOrd = ($UnitsRec->{$UnitType}->{$Row->[2]} * 10 + $ExecOrd ) * 10 + $Row->[6];
				## WrLog("Debug - calling $Func at Line: " . __LINE__);
				my $NewNode=$Func->($Row,$ExecOrd );
				exists $InstallTree{$UnitType} or WrLog("Error - No Root Value for Unit Type $UnitType");
				$NewNode and $InstallTree{$UnitType}->appendChild($NewNode);
			}
			##WrLog("Debug - Line: " . __LINE__);
			###### Check for Virtual Params  ####
			exists $G_CLIParams{D} and WrLog("Debug - Install Table Procedur: start Search Virtual Params at Line");
			foreach my $TmpStr ( @$Row[3..5,8] ) 
			{
				$TmpStr and exists $G_CLIParams{D} and WrLog("Debug - Parsing Line: \"$TmpStr\"");
				####  Just Copy String To avoide deletion of data ...
				my $CopyStr=$TmpStr;
				while ( $CopyStr =~ s/\{([^\}]+?)\}//  ) 
				{
					my $ParamName=$1;
					exists $UnitsRec->{$UnitType}->{VirtualParams} or $UnitsRec->{$UnitType}->{VirtualParams}={};
					$UnitsRec->{$UnitType}->{VirtualParams}->{$ParamName}=$Row->[2];
					exists $G_CLIParams{D} and WrLog("Debug - Install Add Virtaul Param \"$ParamName\" to ExeGroup $Row->[2]");
				}
			}
		}
	}
	return $Err;
}

sub AddUninstall
##############################################################################
#
# Input:	$MdbObj , \%UnitRec
#			$MdbObj is mdb Object - Object That Handle mdb files ( it create via mdbReader::Parser )
#			This object should be already initial when calling this procedure.
#			\%UnitRec - Pointer to Hash file that contain the Unit Record - key=UnitName, Value - Pointer
#						to UnitRec (see Unit Rec content at "setUnitsRec" Func
#		
# Return:	0 - O.K , 1 - Error
#
# Description: This Procedure Parse the "UnInstall" table at mdb file and update the relevant
#				CAF with the execution commands + UAF with the uninstall component.
#
###############################################################################
{
	my $MdbObj = shift ;
	my $UnitsRec = shift;
	my %Operation = ( Copy	=> [\&AddCopy,0] ,
			  Batch	=> [\&AddBatch,3,\&CopyExec,0] ,
			  PostBatch => [\&AddBatch,5,\&CopyExec,3] ,
			  PreBatch => [\&AddBatch,-3,\&CopyExec,-5] );
	my $Err=0;
	my %UnInstallTree;
	my %UAFList;
	#### Read UnInstal Table
	exists $G_CLIParams{D} and  WrLog("Debug - Parsing Uninstall Table at file $MdbObj->{FileName}");
	my $InstTable=$MdbObj->getTableByName("Uninstall");
	$InstTable or return 0;
	my @CmdList=$InstTable->getRows("OperationType","Platform","ProductName","Param1","Param2","Param3","ExecutionOrder","PauseAfter","UnitTypeFilter","InstallSerial");
	exists $G_CLIParams{D} and WrLog(sprintf("Debug - Found out at table uninstall %d relevant rows",$#CmdList+1));

	while ( my ($UnitName,$UnitRec1) = each(%$UnitsRec)) 
	{
		exists $G_CLIParams{D} and WrLog("Debug - AddUnInstalltion: initiat Unit \"$UnitName\" - Xml Obj: $UnitRec1:",%$UnitRec1);
		
		
		$UnInstallTree{$UnitName}=ValidatePath($UnitRec1->{CAFXml}->documentElement(),"//Component/Uninstall");
		unless ( ref($UnInstallTree{$UnitName}) )
		{
			WrLog("Error - Fail to create Uninstall Section at file $UnitRec1->{CAFObj}->{FileName}");
			$Err++;
			delete $UnInstallTree{$UnitName};
		}
	}
	foreach my $Row (@CmdList) 
	{
		exists $G_CLIParams{D} and WrLog("Debug Row Values:",@$Row);
		$Row->[1] =~ /Linux/i or next;
		unless ( exists $Operation{$Row->[0]} ) 
		{
			WrLog("Error - Unknown operation \"$Row->[0]\" at LineOrder $Row->[-1]");
			$Err++;
			next;
		}
		### Check ProductName !!!!  ###
		my @UnitsList=$Row->[8] ? split(/[,;]/,$Row->[8]) : keys(%UnInstallTree) ;

		foreach my $UnitType ( @UnitsList ) 
		{
			### Check if the product is relvalt to the Unit type ...###
			### Validate that UnitType is not a parameter ###
			##WrLog("Debug - Exec For Unit \"$UnitType\"");
			if ( $UnitType =~ s/\{([^\}]+?)\}// ) 
			{
				$UnitType=$1;
				$UnitType =~ s/\s//g ;
				unless ( exists $UnitsRec->{$UnitType} ) 
				{
					$Err += CreateVirtualUnit($UnitType,$Row->[2],$UnitsRec,$MdbObj->{FileName});
				}
				$UnInstallTree{$UnitType}=ValidatePath($UnitsRec->{$UnitType}->{CAFXml}->documentElement(),"//Component/Uninstall");
			} elsif ( ! exists $UnitsRec->{$UnitType} or exists $UnitsRec->{$UnitType}->{VFlag} ) 
			{
				###### Skip Unit Type that R used for UnitType Filter ###
				next;
			}


			exists $UnitsRec->{$UnitType} or next ;
			exists $UnitsRec->{$UnitType}->{$Row->[2]} or next ;


			#### Create Relevant Node   ####
			my @ExecList=@{$Operation{$Row->[0]}};
			while ( @ExecList ) 
			{
				my $Func=shift(@ExecList);
				my $ExecOrd=shift(@ExecList);
				$ExecOrd = ($UnitsRec->{$UnitType}->{$Row->[2]} * 10 + $ExecOrd ) * 10 + $Row->[6];
				## WrLog("Debug - calling $Func at Line: " . __LINE__);
				my $NewNode=$Func->($Row,$ExecOrd );
				exists $UnInstallTree{$UnitType} or WrLog("Error - No Root Value for Unit Type $UnitType");
				$NewNode and $UnInstallTree{$UnitType}->appendChild($NewNode);
				$UAFList{$UnitType}=$UnitsRec->{$UnitType}->{UAFXml};
			}
			##WrLog("Debug - Line: " . __LINE__);
			
		}
	}
	
	#### Update Uaf with new component  ###
	while ( my ($Unit,$UAFObj) = each (%UAFList) )
	{
		####    Find some Component Variable
		my @List=$UnitsRec->{$Unit}->{CAFXml}->documentElement()->findnodes("//Component");
		@List or next;
		my $CompName=$List[0]->getAttribute("Name");
		
		my $UAFTree=ValidatePath($UAFObj->documentElement(),"//UnitType/Uninstall");
		my $CompLeaf=$UAFTree->appendChild(XML::LibXML::Element->new("Component"));
		$CompLeaf->setAttribute("Name",$CompName);
	}
	return $Err;
}

sub ValidatePath # $XMLObj , Xpath
{
	my $XMLObj=shift;
	my $XPath=shift;
	my $LastNode;
	#WrLog("Debug - ValidatePath: Input: $XPath");
	$XPath or return ;
	$XMLObj or WrLog(sprintf("Error - calling validate with undefined Xmlobj %s %s %d",caller));
	my @TmpNodes=$XMLObj->findnodes($XPath);
	#WrLog("Debug - After searching $XPath - Found out @TmpNodes");
	@TmpNodes and return $TmpNodes[0];
	$XPath =~ s/[\/]?([^\/]+)$// and $LastNode=$1;
	my $Owner=ValidatePath($XMLObj,$XPath);
	$Owner or WrLog("Error - Fail to find/ create ($XPath)/$LastNode"),return;
	$LastNode=XML::LibXML::Element->new($LastNode);
	return $Owner->appendChild($LastNode);
}

sub getxmlPath
{
	return ("XML",shift);
}

sub getiniPath
{
	my $IniPath=shift;
	$IniPath =~ /\[(.+)\](.+)/ or WrLog("Error - Unknown Ini Parameter Format \"$IniPath\"");
	return ("INI","$1.$2");
}

sub getTxtPath
{
	my $TxtPath=shift;
	$TxtPath =~ s/^[\/]// ;
	$TxtPath =~ s/\[(.+)\]// or return ("KeyValue",$TxtPath);
	my $Params=$1;
	$Params =~ /(^|\s)r\s*/ and return ("Text",$TxtPath);
	return ("Properties",$TxtPath);
}

sub setParamType ## \@Row return Retrictions node
{
	my $Field=shift;
	my $TNode=XML::LibXML::Element->new("Restrictions");
	if ( $Field->[8] =~ /([-]?\d+)-(\d+)/ or $Field->[10] ) 
	{	####  Numeric Parameter 
		my ($MinVal,$MaxVal)=($1,$2);
		exists $G_CLIParams{D} and WrLog("Debug - Set $Field->[-1] as Number");
		$TNode->appendTextChild("Type","Number");
		if ( $MaxVal > $MinVal ) 
		{
			$TNode->appendTextChild("MinVal",$MinVal);
			$TNode->appendTextChild("MaxVal",$MaxVal);
		}
	} elsif ( $Field->[8] ) 
	{    ### Enum Parameter
		exists $G_CLIParams{D} and WrLog("Debug - Set $Field->[-1] as Enum");
		$TNode->appendTextChild("Type","Enum");
		my $TmpNode=XML::LibXML::Element->new("Enum");
		my @ItemList=split(/[,;]/,$Field->[8]);
		while ( @ItemList ) 
		{
			my $ItemNode=XML::LibXML::Element->new("Item");
			$ItemNode->setAttribute("Value",shift(@ItemList));
			$Field->[9] and $ItemNode->setAttribute("Display",shift(@ItemList));
			$TmpNode->appendChild($ItemNode);
		}
		$TNode->appendChild($TmpNode);
	} else 
	{   ## String Parameter
		$TNode->appendTextChild("Type","String");
	}
	return $TNode;
}

sub AddParameter
{
	my $MdbObj = shift ;
	my $UnitsRec=shift;
	my $Err=0;
	my %LevelDef= (  1 => "System" ,
					 2 => "UnitType" ,
				     4 => "Unit" );
	my %FileTypeParser = ( xml	=> \&getxmlPath ,
						   ini	=> \&getiniPath ,
						   txt  => \&getTxtPath  );
	my %InstallTree;
	my $MaskStr=join('|',keys(%FileTypeParser));
	my $GroupName="Tmp Group";
	exists $G_CLIParams{D} and WrLog("Debug - Reading Parameters table");
	my $ParamsTable=$MdbObj->getTableByName("Parameters");
	my @ParamsList=$ParamsTable->getRows("ProductName",	  ##  0
										"InstallationValue", ##  1
										"ParameterPath",	  ##	2
										"TreeLevel",	  ##	3
										"Default",		  ##	4
										"Platform",	  ##	5
					     "UnitTypeFilter",	  ##	6
					"Description",		##	7
					"range",		##	8
					 "IsRangeWithColumns",	##	9
					 "IsParameterValueNumeric", # 10
					 "Name");		##  11
	unless ( @ParamsList) 
	{
		WrLog("Warning - Parameters List table is empty.");
		return ;
	}
	######   Set Base Parameters Node  for each CAF File (Unit Type)
	while ( my ($UnitName,$UnitRec) = each(%$UnitsRec)) 
	{
		exists $G_CLIParams{D} and exists $UnitRec->{VFlag} and  WrLog("Debug - UnitType \"$UnitName\" is virtual (By UnitypeFilter} created at Component $UnitRec->{VFlag}");
		exists $UnitRec->{CAFXml} or WrLog("Error - Unit $UnitName does not have CAF Object !");
		## $InstallTree{$UnitName}=ValidatePath($UnitRec->{CAFXml}->documentElement(),"//Component/Parameters");
		$InstallTree{$UnitName}=ValidatePath($UnitRec->{CAFXml},"//Component/Parameters");
		ref($InstallTree{$UnitName}) and next;
		WrLog("Error - Fail to create Parameters Section at file $UnitRec->{CAFObj}->{FileName}");
		$Err++;
		delete $InstallTree{$UnitName};
	}
	foreach my $Field (@ParamsList) 
	{
		### Filter un relevant Lines ###
		$Field->[5] =~ /Linux/i or next;  ## Platform Filter
		my $ParamName=$Field->[2] =~ /^\s*\{([^\{\}]+?)\}\s*$/ ? $1 : $Field->[-1];
		my $ParamLevel=exists($LevelDef{$Field->[3]}) ? $LevelDef{$Field->[3]} : "Unsupported level $Field->[3]" ;
		my $ConstValFlag= ( $Field->[1] eq "" or  $Field->[1] =~ /\{.+\}/ ) ? 0 : 1;
		my $DefVal= $ConstValFlag ? $Field->[1] : $Field->[4];
		my $Descript= $Field->[7] ? $Field->[7] : undef ;

		######  Set Type definision   ####
		my $TNode=setParamType($Field);

		my $GroupFlag=0;
		my $ChiledNode;
		if ( $Field->[2] ) 
		{     ####    This is Physical Parameter with File Path   ####
			unless ( $Field->[2]=~ /($MaskStr):\/\/(.+?)\/([\/\[].+)/ ) 
			{
				WrLog("Error - Parameter $Field->[-1] has Unsuported Path \"$Field->[2]\" Skip this Parameter");
				$Err++;
				next;
			} 
			my $FilePath=$2;
			### WrLog("Debug - $1  :  $2   = $3 ($Field->[2])");
			my @Valid=$FileTypeParser{$1}->($3);
			$ChiledNode=XML::LibXML::Element->new("File");
			$ChiledNode->setAttribute("Name",$FilePath);
			$ChiledNode->setAttribute("Format",$Valid[0]);
			$ChiledNode->setAttribute("ParameterPath",$Valid[1]);
		} else 
		{    ##### This is Virtual Parameter
			$ChiledNode=XML::LibXML::Element->new("Group");
			$ChiledNode->setAttribute("Name",$GroupName);
			$ChiledNode->setAttribute("DefaultInstances",1);
			$ChiledNode->setAttribute("MaxOccur",1);
			$GroupFlag=1;
		}


		my @UnitsList=$Field->[6] ? split(/[,;]/,$Field->[6]) : keys(%InstallTree) ;
		foreach my $UnitType ( @UnitsList ) 
		{
			
			####   Set Unit Filter 			
			if ( $UnitType =~ s/\{([^\}]+?)\}// ) 
			{
				$UnitType=$1;
				$UnitType =~ s/\s//g ;
				unless ( exists $UnitsRec->{$UnitType} ) 
				{
					$Err += CreateVirtualUnit($UnitType,$Field->[0],$UnitsRec,$MdbObj->{FileName}); 
					$Err and WrLog("Error - Failed to create Virtual Unit $UnitType ...");
					$InstallTree{$UnitType}=ValidatePath($UnitsRec->{$UnitType}->{CAFXml},"//Component/Parameters");
				} 
			} 

			exists $UnitsRec->{$UnitType} or WrLog("Warning - Unsupported Unit Filter \"$UnitType\" at Parameters table parameter \"$Field->[-1]\""),next;
			exists $G_CLIParams{D} and ( exists $UnitsRec->{$UnitType}->{$Field->[0]} or WrLog("Debug - \"$ParamName\" is skiped not relvant to product $Field->[0] at Unit $UnitType"));
			exists $UnitsRec->{$UnitType}->{$Field->[0]} or next ;
			## $UnitsRec->{$UnitType}->{VFlag} and ! $Field->[6] and WrLog("Debug - Skip update parameter \"$Field->[-1]\" for $UnitType ($UnitsRec->{$UnitType}->{VFlag}) ...$Field->[6]");
			$UnitsRec->{$UnitType}->{VFlag} and ! $Field->[6] and next;

			###### Check for Virtual Params  ####
			foreach my $TmpStr ( @$Field[0,1,6] ) 
			{
				my $TmpBuf=$TmpStr ;
				while ( $TmpBuf =~ s/\{([^\}]+)\}//  ) 
				{
					my $ParamName=$1;
					exists $UnitsRec->{$UnitType}->{VirtualParams} or $UnitsRec->{$UnitType}->{VirtualParams}={};
					$UnitsRec->{$UnitType}->{VirtualParams}->{$ParamName}=$Field->[0];
				}
			}
			my $ParmeterNode=XML::LibXML::Element->new("Parameter");
			$ParmeterNode->setAttribute("Name",$ParamName);
			$ParmeterNode->setAttribute("ExecutionGroup",$Field->[0]);
			my @TmpNodes=$UnitsRec->{$UnitType}->{CAFXml}->findnodes("//Parameters/Parameter[\@Name=\"$ParamName\" and \@ExecutionGroup=\"$Field->[0]\"]");
			$ParmeterNode = @TmpNodes ? $TmpNodes[0] : $InstallTree{$UnitType}->appendChild($ParmeterNode);
			unless ( $ParmeterNode) 
			{
				WrLog("Error - Fail to create Parameter \"$ParamName\"");
				$Err++;
				next ;
			}
			$ParmeterNode->setAttribute("Level",$ParamLevel);
			if ( $ConstValFlag ) 
			{
				my $DispName=$ParamName;
				##$DispName =~ s/\s+//g;
				exists $G_CLIParams{D} and WrLog("Debug - $DispName hase constant Value \"$DefVal\"");
				unless ( exists $UnitsRec->{VirtualParams} and exists $UnitsRec->{VirtualParams}->{$DispName} ) 
				{
					$ParmeterNode->setAttribute("Display",0);
				}
			}
			
			$DefVal and $ParmeterNode->appendTextChild("Value",$DefVal);
			$Descript and $ParmeterNode->appendTextChild("Description",$Descript);
			my $TMpMem=$ParmeterNode->appendChild($TNode->cloneNode(3));
			
			exists $G_CLIParams{D} and WrLog("Debug - Add to \"$ParamName\" Type: ",$TMpMem->toString());

			my $TmpParamNode=ValidatePath($UnitsRec->{$UnitType}->{CAFXml},$GroupFlag ? "//Component/Groups" : 
						"//Parameters/Parameter[\@Name=\"$ParamName\" and \@ExecutionGroup=\"$Field->[0]\"]/Files") ;
			my $AddFlag= ($TmpParamNode->nodePath() !~ /File/i and $TmpParamNode->findnodes("//Component/Groups/Group") ) ? 0 : 1;
			## $AddFlag and $TmpParamNode->nodePath() =~ /Group/ and $ChiledNode=undef;
			$AddFlag and $TmpParamNode=$TmpParamNode->appendChild($ChiledNode->cloneNode(3));
			####   Add Set Params   ####
			@TmpNodes=$UnitsRec->{$UnitType}->{CAFXml}->findnodes("//Component/Install/SetParams[ExecutionGroup=\"$Field->[0]\"]");
			@TmpNodes and next;
			### Add SetParams Command
			## my $ExceOrder=$UnitsRec->{$UnitType}->{$Field->[0]} + 1 ;
			my $ExceOrder=$UnitsRec->{$UnitType}->{$Field->[0]} *100 + 12 ;
			my $TmpInstallNode=ValidatePath($UnitsRec->{$UnitType}->{CAFXml},"//Component/Install");
			## WrLog("Debug - TmpNode after Install Xpath search $TmpNode");
			@TmpNodes=$UnitsRec->{$UnitType}->{CAFXml}->findnodes("//Component/Install/SetParams[\@ExecutionOrder=\"$ExceOrder\"]");
			unless ( @TmpNodes ) 
			{
				$TmpInstallNode=$TmpInstallNode->appendChild(XML::LibXML::Element->new("SetParams"));
				$TmpInstallNode->setAttribute("ExecutionOrder",$ExceOrder);
			} else { $TmpInstallNode=$TmpNodes[0] ;}
			$TmpInstallNode->appendTextChild("ExecutionGroup",$Field->[0]);
		}
	}
		#####    Add Virtual Parameters     ######
	while ( my ($UnitName,$UnitRec) = each(%$UnitsRec)) 
	{
		exists $UnitRec->{VirtualParams} or next;
		exists $InstallTree{$UnitName} or WrLog("Error - Unit $UnitName does not have CAF Object or Parameters Section!"),$Err++,next;
		while ( my ($ParamName,$ExcGroup) = each(%{$UnitRec->{VirtualParams}}) )  
		{
			my @TmpNodes=$InstallTree{$UnitName}->findnodes("//Parameters/Parameter[\@Name=\"$ParamName\"]");
			@TmpNodes and next;
			my $TmpNode=$InstallTree{$UnitName}->appendChild(XML::LibXML::Element->new("Parameter"));
			$TmpNode->setAttribute("Name",$ParamName);
			$TmpNode->setAttribute("Level","System");
			$TmpNode->setAttribute("ExecutionGroup",$ExcGroup);
			$TmpNode=$TmpNode->appendChild(XML::LibXML::Element->new("Restrictions"));
			$TmpNode=$TmpNode->appendTextChild("Type","String");
			exists $G_CLIParams{D} and WrLog("Debug - Virtual Parametr \"$ParamName\" Added to CAF");
		}
				
	}
	while ( my ($UnitName,$UnitRec) = each(%$UnitsRec)) 
	{
		#### Clean Parameters Tree if it is empty
		$UnitRec->{CAFXml}->findnodes("//Component/Parameters/Parameter") and next;
		my @TmpNodes=$UnitRec->{CAFXml}->findnodes("//Component/Parameters");
		@TmpNodes and $TmpNodes[0]->parentNode()->removeChild($TmpNodes[0]);
	}
	return $Err;
}

sub SearchDir
{
	my $Patern=shift;
	my $Dir=shift;
	my @FileList;
	my @DirList;
	my @Result;
	opendir(MDBDir,$Dir) or return;
	my @LocalFileList=readdir(MDBDir);
	close MDBDir;
	foreach my $File (@LocalFileList) 
	{
		$File =~ /\.(\.|$)/ and next;
		-d "$Dir/$File" and push(@DirList,"$Dir/$File"),next;
		$File =~ /$Patern/ and push(@FileList,"$Dir/$File") ;
	}
	return (\@FileList,\@DirList);
}

sub getFileList
{
	my @FileList=@_;
	my @Result;
	foreach my $FPath (@FileList) 
	{
		## WrLog("Debug - Checking: $FPath");
		-d $FPath or push(@Result,$FPath) , next;
		## WrLog("Debug - $FPath is not a file ...");
		my @DirList=($FPath);
		for ( my $DirLevel=$G_CLIParams{SearchLevel}; $DirLevel ; $DirLevel-- ) 
		{
			my @NextLevel=();
			foreach my $Dir ( @DirList ) 
			{
				my @DirLevelList=SearchDir(".+\.mdb\$",$Dir);
				## WrLog("Debug - Files:",@{$DirLevelList[1]});
				push(@Result,@{$DirLevelList[0]});
				## WrLog("Debug - Dirs:",@{$DirLevelList[0]});
				push(@NextLevel,@{$DirLevelList[1]});
			}
			@DirList=@NextLevel;
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
my %Options= ( Loger => \&WrLog) ;
my $DebugFlag=$G_CLIParams{D} or "Debug" ;
foreach my $Iter (split(',',$G_CLIParams{D})) 
{
	$Options{$Iter}=1;
}

my %UnitMap=ReadUnitMap($G_CLIParams{Map});
my %UListRec;
my $ErrFlag;

%UnitMap or $G_ErrorCounter++, delete $G_CLIParams{File};

foreach my $MdbFileName ( getFileList(split(',',$G_CLIParams{File})) ) 
{
	WrLog("Info  - Start analyze \"$MdbFileName\"");
	$ErrFlag=$G_ErrorCounter;
	my $MdbObj=mdbReader::Parser->parse_file($MdbFileName,%Options);
	defined $MdbObj or $G_ErrorCounter++;
	$G_ErrorCounter > $ErrFlag and WrLog("Error - Fail to Read $MdbFileName Skip this Octopus kit"),next;
	%UListRec = setUnitsRec($MdbObj,\%UnitMap);
	# WrLog("Debug - Finish to set Units ($G_ErrorCounter)",%UListRec);
	$G_ErrorCounter > $ErrFlag and WrLog("Error - SWIM Kit of $MdbFileName may have mising unit support");
	$ErrFlag=$G_ErrorCounter;
	$G_ErrorCounter += AddInstalltion($MdbObj,\%UListRec);
	# WrLog("Debug - Finish to add Install instarctions ($G_ErrorCounter)");

	### Just go over all Hash file to verify no Hash record will be deleted by the perl memory management
	foreach my $Tmp (%UListRec ) {}
	$G_ErrorCounter += AddParameter($MdbObj,\%UListRec);
	$G_ErrorCounter += AddUninstall($MdbObj,\%UListRec);
	exists $G_CLIParams{IgnoreError} and WrLog("Debug - Ignore errors and build CAF File($G_ErrorCounter)");
	unless ( $G_ErrorCounter > $ErrFlag and ! exists $G_CLIParams{IgnoreError} ) 
	{
		while ( my ($UnitType,$RecPoint) = each(%UListRec) ) 
		{
			##WrLog("Debug - Going to save $UnitType CAF File");
			##exists $RecPoint->{CAFXml} or WrLog("$RecPoint",keys(%UListRec));
			$G_ErrorCounter += $RecPoint->{CAFXml}->toFile($RecPoint->{CAFFileName},1) ? 0 : 1;	
			WrLog("Info  - CafFile $RecPoint->{CAFFileName} have been Created");
			my $TmpStr=$RecPoint->{UAFXml}->toString();
			$TmpStr =~ s/>\s+</></g ;
			my $TmpXmlObj=XML::LibXML->new()->parse_string($TmpStr);
			$G_ErrorCounter  += $TmpXmlObj->toFile($RecPoint->{UAFFileName},1) ? 0 : 1;
		    WrLog("Info  - UAFFile $RecPoint->{UAFFileName} have been Created");
		}
	}
	$G_ErrorCounter > $ErrFlag and WrLog("Info  - SWIM kit conversion of $MdbFileName is not completely converted - need to do some manual changes");
}

my $ErrMessage= $G_ErrorCounter ? "Finish with ERRORS see Log File $G_CLIParams{LogFile}" :
		"Finish Successfully :-)";
EndProg($G_ErrorCounter,$ErrMessage);