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
				   DefaultDir => "/tmp" ) ;
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
{
	my $Mdbobj=shift;
	my $ProductTable=$Mdbobj->getTableByName("Products");
	my @ProList=$ProductTable->getRows("ProductName","InstallationPhaseNumber","Depends");
	my %Result;
	###Sort Products  ###
	foreach my $Row ( @ProList ) 
	{
		$Result{$$Row[0]}=$$Row[1] * 10 ;
	}
	##### Check depenedenc
	my $SortFlag=1;
	while ( $SortFlag ) 
	{
		$SortFlag=0;
		foreach my $Row ( @ProList ) 
		{
			$$Row[2] or next;
			WrLog("Debug - Product $$Row[0] has depend \"$$Row[2]\"");
			#### Find maximum depend  ####
			my $Depend=0;
			foreach my $ProdName ( split(/[,;]/,$$Row[2]) ) 
			{
				$Result{$ProdName} > $Depend and $Depend=$Result{$ProdName};
			}
			$Result{$$Row[0]} > $Depend and next ;
			$SortFlag=1;
			$Result{$$Row[0]} = $Depend + 5 ;
		}
	}
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
	my $Result=XML::LibXML::Element->new("Execute");
	$Result->setAttribute("ExecutionOrder",$ExecOrd);
	$Row->[7] and  $Result->setAttribute("Timeout",$Row->[7]);
	$Result->appendTextChild("Command","$Target $Row->[5]");
	return $Result;
}

sub AddCopy ## \@Row , $Exeution Order
{
	my $Row=shift;
	my $ExecOrd=shift;
	my $Result=XML::LibXML::Element->new("Copy");
	$Result->setAttribute("ExecutionOrder",$ExecOrd);
	$Result->appendTextChild("Source",$Row->[3]);
    $Result->appendTextChild("Target",$Row->[4]);
	return $Result;
}

sub CopyExec
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
	my $Result=XML::LibXML::Element->new("Copy");
	$Result->setAttribute("ExecutionOrder",$ExecOrd);
	$Result->setAttribute("ChmodFlags","+x");
	$Result->appendTextChild("Source",$Row->[3]);
    $Result->appendTextChild("Target",$Target);
	return $Result;
}


sub AddInstalltion  ####  ($MdbObj,$CAFObj,\%ExecOrder);
{
	my $MdbObj = shift ;
	my $CAFObj = shift ;
	my $ProductOrd = shift;
	my %Operation = ( Copy	=> [\&AddCopy,0] ,
					  Batch	=> [\&AddBatch,2,\&CopyExec,0] ,
					  PostBatch => [\&AddBatch,3,\&CopyExec,0] ,
					  preBatch => [\&AddBatch,-2,\&CopyExec,-3] );
	my $Err=0;
	#### Read Instal Table
	WrLog("","","Debug ####################################","Debug - Reading install Table","###########################","");
	my $InstTable=$MdbObj->getTableByName("Install");
		WrLog("","","Debug ####################################","Debug - Reading install Rows Table","###########################","");
	my @CmdList=$InstTable->getRows("OperationType","Platform","ProductName","Param1","Param2","Param3","ExecutionOrder","PauseAfter","UnitTypeFilter","InstallSerial");
	my @ExecNode=$CAFObj->findnodes("//Component/Install");
	unless ( @ExecNode ) 
	{
		@ExecNode=$CAFObj->findnodes("//Component");
		$ExecNode[0]->appendChild(XML::LibXML::Element->new("Install"));
		@ExecNode=$CAFObj->findnodes("//Component/Install");
	} 
	WrLog(sprintf("Debug - Foundout at table install %d relevant rows",@CmdList));
	foreach my $Row (@CmdList) 
	{
		WrLog("Debug Row :",@$Row);
		$Row->[1] =~ /Linux/i or next;
		unless ( exists $Operation{$Row->[0]} ) 
		{
			WrLog("Error - Unknown operation \"$Row->[0]\" at LineOrder $Row->[-1]");
			$Err++;
			next;
		}
		### Check ProductName !!!!  ###
		WrLog("Debug - Start Analayze $Row->[0] at product $Row->[2]");
		unless ( exists $ProductOrd->{$Row->[2]} ) 
		{
			WrLog("Error - Unknown Product \"$Row->[2]\" at LineOrder $Row->[-1]");
			$Err++;
			next;
		}
		#### Create Relevant Node   ####
		my @ExecList=@{$Operation{$Row->[0]}};
		while ( @ExecList ) 
		{
			my $Func=shift(@ExecList);
			my $ExecOrd=shift(@ExecList);
			my $NewNode=$Func->($Row,$ProductOrd->{$Row->[2]} + $ExecOrd );
		    $ExecNode[0]->appendChild($NewNode);
		}
	}
	return $Err;
}



sub CreateCAF   ### $MdbObj
{
	## my $FileName=shift;
	my $MdbObj=shift;
	my $GenTable=$MdbObj->getTableByName("General");
	my @Rows=$GenTable->getRows("Version");
	my $FileName=$MdbObj->{FileName};
	my $Component=$FileName;
	$Component =~ s/^.+[\/\\]// ;
	$Component =~ s/\.mdb//i ;
	WrLog("Debug - Create Component Element \"$Component\"");
	my $CompObj=XML::LibXML::Element->new("Component");
	$CompObj->setAttribute("Name",$Component);
	$CompObj->setAttribute("Version",$Rows[0]->[0]);
	$CompObj->setAttribute("Platform","Linux");
	my $XmlObj=XML::LibXML::Document->createDocument("1.0","UTF-8");
	my $Root=XML::LibXML::Element->new("SWIM");
	$Root->appendChild($CompObj);
	$XmlObj->setDocumentElement($Root);
	my %Result = ( Xml	=> $XmlObj ,
			       FileName => $Component . "_OctopusAutoGen-CAF.xml" );
	return %Result;
}

sub ValidatePath # $XMLObj , Xpath
{
	my $XMLObj=shift;
	my $XPath=shift;
	my $LastNode;
	#WrLog("Debug - ValidatePath: Input: $XPath");
	$XPath or return ;
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
##	my $Xpath= shift;
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
	$Params =~ /(^|\s)r\s/ and return ("Text",$TxtPath);
	return ("Properties",$TxtPath);
}


sub AddParameter
{
	WrLog("Debug - AddParameter Not Ready yet ...");
	my $MdbObj = shift ;
	my $CAFObj = shift ;
	my $ProductOrd = shift;
	my $Err=0;
	my %LevelDef= (  1 => "System" ,
					 2 => "UnitType" ,
				     4 => "Unit" );
	my %FileTypeParser = ( xml	=> \&getxmlPath ,
						   ini	=> \&getiniPath ,
						   txt  => \&getTxtPath  );
	my $MaskStr=join('|',keys(%FileTypeParser));
	my $GroupName="Tmp Group";
	WrLog("Debug - Reading Parameters table");
	my $ParamsTable=$MdbObj->getTableByName("Parameters");
	my @ParamsList=$ParamsTable->getRows("ProductName","InstallationValue","ParameterPath","TreeLevel","Default","Platform","UnitTypeFilter","Description","range","IsRangeWithColumns","IsParameterValueNumeric","Name");
	unless ( @ParamsList) 
	{
		WrLog("Worning - Parameters List table is empty.");
		return ;
	}
	## my @TmpNodes=$CAFObj->findNodes("//Component/Parameters");
	my $ParamsNode=ValidatePath($CAFObj,"//Component/Parameters"); 
	##$TmpNodes[0];
	unless ( $ParamsNode ) 
	{
		WrLog("Error - Fail to create Parameters section at CAF File");
		return 1;
	}
	foreach my $Field (@ParamsList) 
	{
		### Filter un relevant Lines ###
		$Field->[5] =~ /Linux/i or next;  ## Platform Filter
		my $ParamName=$Field->[5] =~ /^\s*\{([\{\}]+?)\}\s*$/ ? $1 : $Field->[-1];
		
		my $PNode=XML::LibXML::Element->new("Parameter");
		$PNode->setAttribute("Name",$ParamName);
		$PNode->setAttribute("ExecutionGroup",$Field->[0]);
		my @TmpNodes=$CAFObj->findnodes("//Parameters/Parameter[\@Name=\"$ParamName\" and \@ExecutionGroup=\"$Field->[0]\"]");
		$PNode= @TmpNodes ? $TmpNodes[0] : $ParamsNode->appendChild($PNode);

		unless ( $PNode) 
		{
			WrLog("Error - Fail to create Parameter \"$ParamName\"");
			$Err++;
			next ;
		}
		$PNode->setAttribute("Level",exists($LevelDef{$Field->[3]}) ? $LevelDef{$Field->[3]} : "Unsupported level $Field->[3]");
		my $DefVal= $Field->[1] =~ /\{.+\}/ ? $Field->[4] : $Field->[1];
		$DefVal and $PNode->appendTextChild("Value",$DefVal);
		$Field->[7] and $PNode->appendTextChild("Description",$Field->[7]);
		my $TNode=XML::LibXML::Element->new("Restrictions");
		######  Set Type definision   ####
		if ( $Field->[8] ) 
		{   #### Range number   ###
			$TNode->appendTextChild("Type","Enum");
			my $TmpNode=XML::LibXML::Element->new("Enum");
			my @ItemList=split(/,/,$Field->[8]);
			while ( @ItemList ) 
			{
				my $ItemNode=XML::LibXML::Element->new("Item");
				$ItemNode->setAttribute("Value",shift(@ItemList));
				$Field->[9] and $ItemNode->setAttribute("Display",shift(@ItemList));
				$TmpNode->appendChild($ItemNode);
			}
			$TNode->appendChild($TmpNode);
		} elsif ( $Field->[10] ) 
		{
			#### Numeric Value  ###
			$TNode->appendTextChild("Type","Number");
		} else 
		{
			$TNode->appendTextChild("Type","String");
		}
		$PNode->appendChild($TNode);
		if ( $Field->[2] ) 
		{     ####    This is Physical Parameter with File Path   ####
			$Field->[2]=~ /($MaskStr):\/\/(.+?)\/([\/\[].+)/ ;
			my $FilePath=$2;
			my @Valid=$FileTypeParser{$1}->($3);
			my $FNode=ValidatePath($CAFObj,"//Parameters/Parameter[\@Name=\"$ParamName\" and \@ExecutionGroup=\"$Field->[0]\"]/Files");
			my $FileNode=XML::LibXML::Element->new("File");
			$FileNode->setAttribute("Name",$FilePath);
			$FileNode->setAttribute("Format",$Valid[0]);
			$FileNode->setAttribute("ParameterPath",$Valid[1]);
			$FNode->appendChild($FileNode);
		} else 
		{    ##### This is Virtual Parameter
			$PNode->setAttribute("GroupName",$GroupName);
			my $GName=XML::LibXML::Element->new("Group");
			$GName->setAttribute("Name",$GroupName);
			$GName->setAttribute("DefaultInstances",1);
			$GName->setAttribute("MaxOccur",1);
			my $GroupsNode=ValidatePath($CAFObj,"//Component/Groups");
			my @TmpNodes=$CAFObj->findnodes("//Groups/Group[\@Name=\"$GroupName\"]");
			$GName=@TmpNodes ? $TmpNodes[0] : $GroupsNode->appendChild($GName) ;
		}
		$Field->[6] or next;
		$PNode->appendChild(XML::LibXML::Comment->new("Warning The Following Parameter as UnitFilter Restriction \"$Field->[6]\". check this issue"));
		WrLog("Warning - Parameter ParamName has Unit Filter  Value \"$Field->[6]\". check the CAFFile");
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

my $MdbObj=mdbReader::Parser->parse_file($G_CLIParams{File},%Options);





## $MdbObj=$MdbObj->parse_file($G_CLIParams{File});

defined $MdbObj or $G_ErrorCounter++;

$G_ErrorCounter and EndProg(1,"Fail to create new mdbReader ....");

#WrLog('=' x 200 );
#$MdbObj->Test(100,3);
#my @List = $MdbObj->getPages(102);
#foreach my $Buf (@List) 
#{
#	$Buf->Logger($Buf->{Buf}->toString);
#	WrLog("",'-' x 100,"");
#}
## EndProg(0,"Just Test");

#my $TMMP=$MdbObj->getTableByName("Install");
#my @TTTT=("","Start Get Rows","");
#PrnTitle(@TTTT);
#$TMMP->getRows();
#$MdbObj->getTableList();

#exit 0;

my %CAFObj=CreateCAF($MdbObj);###     XML::LibXML::Element->new("SWIM");

###### get Products and the order exution
my %ExecOrder=getProduct($MdbObj);
$G_ErrorCounter += AddInstalltion($MdbObj,$CAFObj{Xml},\%ExecOrder);
$G_ErrorCounter += AddParameter($MdbObj,$CAFObj{Xml},\%ExecOrder);

unless ( $G_ErrorCounter ) 
{
	my $State=$CAFObj{Xml}->toFile($CAFObj{FileName},1);
	## $G_ErrorCounter += WriteFile($CAFObj{FileName},$CAFObj{Xml}->toString());
	WrLog("Debug - Last command state is $State");
}


my $ErrMessage= $G_ErrorCounter ? "Finish with ERRORS see Log File $G_CLIParams{LogFile}" :
		"Finish Successfully :-)";
EndProg($G_ErrorCounter,$ErrMessage);