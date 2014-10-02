#!/usr/bin/perl

use strict;
#########################################################
#  Global variables
#########################################################

my $G_ErrorCounter=0;
my %G_CLIParams=(  LogFile  => "-" ,
		   Rule	    => "../config/PVVMConf.csv" ,
		   Conf	    => "../config/PVVMConfiguration.conf");
my $G_FieldSeperator="::=";
my @G_MergeTool=("File type,File (full path),Key,Value,Override,Answer file (full path),Token to replace,Backup name (full path),Add property (XML only),XML expression (for evaluation)");
sub usage
{
    print "$0 [-LogFile FileName]\n"
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
# Description:  converte from Hash to singleLine.
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

sub ReadFile
###############################################################################
#
# Input:	$FileName
#
# Return:	@FileLines ( chomped )
#
# Description: if error ocured the global counter $G_ErrorCounter is update 
#
###############################################################################
{
   my $FileName=shift;
   my $Err=0;
   my @Result=();
   
   unless ( -e $FileName )
   {
   	$G_ErrorCounter++;
   	WrLog("Error - File $FileName not exist !");
   	return;
   }
   open INPUT,"< $FileName";
   $Err += $?;
   unless ( $Err )
   {
   	WrLog("Info - Read File $FileName");
   	@Result=<INPUT> ;
   	$Err += $?;
   	chomp (@Result);
   }
   close INPUT;
   $Err += $?;
   if ( $Err )
   {
   	WrLog("Error - Errors during reading file $FileName");
   }
   $G_ErrorCounter += $Err;
   return @Result;
}

sub GetParam
{
    my $HashPointer=shift;
    my $Param=shift;
    my @Systems=@_ ? @_ : keys(%$HashPointer) ;
    my $Result=undef;
    
    foreach my $SysName (@Systems)
    {
    	unless ( defined $$HashPointer{$SysName} )
    	{
    	    WrLog("Error - Systme \"$SysName\" not exist in system configuration file.");
    	    return ;
    	}
    	my @TmpLines=split(';',$$HashPointer{$SysName});
    	my %TmpRecord=ReadSection(@TmpLines);
    	unless ( defined $TmpRecord{$Param} )
    	{
    	    WrLog("Warning - The parameter \"$Param\" is not defined at system $SysName. Ignore system value.");
    	    next;
    	}
    	$Result .= defined $Result ? ";$TmpRecord{$Param}" : $TmpRecord{$Param} ;
    }
    return $Result;
}
sub ReadCsv
###############################################################################
#
# Input:	FileName,Unit,\%Params
#
# Return:	%Records sort by file name
#
# Description:
#
###############################################################################
{
   my $FileName=shift;
   my $Unit=shift;
   my $Platform=shift;
   my $HashPointer=shift;
   my @Result=();
   my $Err=$G_ErrorCounter;
   ## WrLog("Info - Read Rule file \"$FileName\"");
   my @Lines=ReadFile($FileName);
   my (%Record,%Result);
   unless ( $Err == $G_ErrorCounter )
   {
   	WrLog("Error - Fail to read Csv File \"$FileName\"");
   	return ;
   }
   WrLog("-- ReadCsv Input: Unit=$Unit , Platform=$Platform");
   %Result=();
   $Platform = $Platform =~ /Hybid/i ? "Insight4;Insight3" : $Platform ;
   for ( my $Indx=1 ; $Indx <= $#Lines ; $Indx++ )
   {
   	%Record=ReadRecord($Lines[$Indx],$Lines[0]);
   	unless ( $Record{"Unit Type"} =~ /$Unit/i && $Record{Platform} =~ /$Platform/i )
   	{
   		next ;
   	}
   	## WrLog("-- Debug The following Record Match the conditions: " . $Record{"Unit Type"} ." $Record{Platform}");
   	my $FileName=$Record{"File type"} . ':' . $Record{"File Name"};
   	my $Value = $Record{Value};
   	my $NewVal="";
   	while ( $Value =~ m/%([^%]+)%/ )
   	{
   	     $NewVal=GetParam($HashPointer,$1);  ## Need to add default system...
   	     unless ( defined $NewVal )
   	     {
   	     	$Value=$Record{"Parameter Name"};
   	     	WrLog("Error - Fail to find the Parametr at the system answer file.Ignore configuration of $Value");
   	     	last;
   	     }
   	     ## my $Temp = $$HashPointer{$NewVal};
   	     unless ( $Value =~ s/%[^%]+%/$NewVal/ )
   	     {
   	     	WrLog("-Error -- Substytude Failed !");
   	     	foreach ( keys %$HashPointer )
   	     	{
   	     		WrLog ("-- Debug Config Key $_ -> $$HashPointer{$_}");
   	     	}
   	     	last ;
   	     }
   	     
   	}
   	     ## WrLog("-Debug: New Value \"$Value\" -> $Temp");
   	if ( defined $Result{$FileName} ) { $Result{$FileName} .= ';' ;}
   	$Record{"Parametr in File"} =~ s/^\"(.+)\"$/\1/;
   	$Result{$FileName} .= $Record{"Parametr in File"} . $G_FieldSeperator . $Value;
   }
   return %Result;
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
   my $Err=0;
   my %Result=();
   my $HWName="";
   my $Line;
   my @Params=();
   unless ( -e $File )
   {
   	WrLog("Error - File $File not exist !");
   	exit 1;
   }
   WrLog("- Read configuration File $File");
   open INPUT,"< $File";
   $Err=$?;
   while ( <INPUT> )
   {
   	$Line=$_;
   	chomp $Line;
   	if ( $Line =~  m/\[([^\[\]]+)\]/  )
   	{
   	    if ( length($HWName) > 1 )
   	    {
   	    	$Result{$HWName}=join(";",@Params);
   	    }
   	    $HWName=$1;
   	    @Params=();
   	    next;
   	}
   	push (@Params,$Line);
   }
   close INPUT ;
   $Err += $?;
   if ( $Err )
   {
   	WrLog("Error - Fail to read $File");
	exit 1;
   }
   if ( $#Params >=0 )
   {
   	if ( length($HWName) > 0  )
   	{
   	 ##  print "-- Debug Title is \"$HWName\" length " , length($HWName) , "\n";
   	   $Result{$HWName}=join(";",@Params);
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


sub InsertMergeRule #Type,File,Parameter,value
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
    my %Column=();
    $Column{"File type"}=shift;
    $Column{"File (full path)"}=shift;
    $Column{"Key"}=shift;
    $Column{"Value"}=shift;
    $Column{"Override"}="TRUE";
    $Column{"Backup name (full path)"}= ($Column{"File (full path)"} . ".MergeBackup");
    my $Err=0;
    my $CsvNewLine="";
    foreach my $ColumnName (split(',',$G_MergeTool[0]))
    {
    	$CsvNewLine .= "$Column{$ColumnName},";
    	if ( defined $Column{$ColumnName} ) 
    	{ 
    	   undef $Column{$ColumnName}; 
    	   #WrLog("-- Debug Undef \"$ColumnName\" -");
    	}
    }
    
    foreach ( keys(%Column) )
    {
    	unless ( defined $Column{$_} ) { next; }
    	WrLog("Error - Column \"$_\" ($Column{$_}) Not exist at csv file. This parameter will be ignore.");
    	$Err++;
    }
    unless ( $Err )
    {
    	push(@G_MergeTool,$CsvNewLine);
    }
    return $Err;	
}

sub SetParamXpath
###############################################################################
#
# Input:	$RulesList,$FileName
#
# Return:	0 - O.K , 1 Eror
#
# Description:  Change the value of Xpath parameter
#
###############################################################################
{
    ## my $Xpath=shift;
    my $Rules=shift;
    my $FileName=shift;
    my $Err=$G_ErrorCounter;
    unless ( -e $FileName )
    {
    	WrLog("Info\tFile $FileName Not exist. Skip configuration of this file.");
    	return 0;
    }
    foreach my $ParamRecord ( split(';',$Rules) )
    {
     	my @Param = split($G_FieldSeperator,$ParamRecord);
     	$Param[0] =~ s/\/([^\/]+)\/?// ; ## Remove Root Element
     	$Param[0] =~ s/\//\./g ;
     	if ( InsertMergeRule("xml",$FileName,@Param) )
     	{
     	    WrLog("Error - Fail to update Csv file for merge tool. parameter $Param[0] Skiped.");
     	    $Err++;
     	}
    }
    return $Err - $G_ErrorCounter;
}

sub SetIniParam
###############################################################################
#
# Input:	$RuleList,$FileName  \@Lines
#
# Return:
#
# Description:
#
###############################################################################
{
    my $Rules=shift;
    my $FileName=shift;
    my $Err=$G_ErrorCounter;
    
    unless ( -e $FileName )
    {
    	WrLog("Info\tFile $FileName Not exist. Skip configuration of this file.");
    	return 0;
    }
    foreach my $ParamRecord ( split(';',$Rules) )
    {
     	my @Param = split($G_FieldSeperator,$ParamRecord);
     	$Param[0] =~ s/\[([^\]]+)\](.+)$/\1\.\2/ ;
     	if ( InsertMergeRule("ini",$FileName,@Param) )
     	{
     	    WrLog("Error - Fail to update Csv file for merge tool. parameter $Param[0] Skiped.");
     	    $Err++;
     	}
    }
    return $Err - $G_ErrorCounter;
}

sub SetTxtParam
###############################################################################
#
# Input:	$RuleList,$FileName  \@Lines
#
# Return:
#
# Description:
#
###############################################################################
{
    my $Rules=shift;
    my $FileName=shift;
    my $Err=$G_ErrorCounter;
    
    unless ( -e $FileName )
    {
    	WrLog("Info\tFile $FileName Not exist. Skip configuration of this file.");
    	return 0;
    }
    foreach my $ParamRecord ( split(';',$Rules) )
    {
     	my @Param = split($G_FieldSeperator,$ParamRecord);
     	if ( InsertMergeRule("properties",$FileName,@Param) )
     	{
     	    WrLog("Error - Fail to update Csv file for merge tool. parameter $Param[0] Skiped.");
     	    $Err++;
     	}
    }
    return $Err - $G_ErrorCounter;
}

sub SetViaShell
{
    my $Params=shift;
    my $Cmd=shift;
    $Params =~ s/.*$G_FieldSeperator// ;
    $Params =~ s/^\"|\"$//g ;
    $Params =~ s/\\\"/\"/g ;
    return RunCmds("$Cmd $Params");
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
   
   unless ( $Backup || ! -e $FileName )
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

sub ReadRecord  ## ($Rules,$G_RulsList{Title});
{
    my $Line=shift;
    my $Title=shift;
    my @FieldsName=split(',',$Title);
    my @FieldsValue=split(',',$Line);
    my %Result=();
    
    for ( my $i = 0; $i < $#FieldsName; $i++ )
    {
    	if ( $i > $#FieldsValue )
    	{
    	    
    	    WrLog("Warning - Number of Fields value at Record \"$FieldsValue[0]\" is less than required.",
    	    	  "\t- set $FieldsName[$i] Null");
    	    my @Stam=();
    	    foreach ( keys %Result )
    	    {
    	    	push(@Stam,"\t- $_=$Result{$_}");
    	    }
    	    WrLog(@Stam);
    	    last ;
    	}
    	$Result{$FieldsName[$i]}=$FieldsValue[$i];
    }
    return %Result;
}

sub GetMergeTool
{
    my $MergePath="/usr/cti/vi_configuration_merger";
    my @FileList=("runConfigurationMerger.sh",
    		  "commons-collections.jar" ,
    		  "commons-lang.jar" ,
    		  "opencsv-1.8.jar" ,
    		  "conf-util.jar" ,
		  "commons-configuration-1.6.jar" ,  
		  "commons-logging.jar" );
		  
    foreach ( @FileList )
    {
    	unless ( -e "$MergePath/$_" )
    	{
    	   WrLog("Error - some of the mergetoo files is missing ($_). can not run merge tool.");
    	   return "";
    	}
    }
    return "$MergePath/$FileList[0]";
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
    my @MustParams=("Unit","Platform","Conf","Rule");
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
    foreach (@MustParams)
    {
    	unless ( defined $G_CLIParams{$_} )
    	{
    	    WrLog("Error - missing Command line Parameter \"$_\"");
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

my %FileEdit=( xml	=>	\&SetParamXpath,
	       ini	=>	\&SetIniParam ,
	       txt	=>	\&SetTxtParam ,
	       sh	=>	\&SetViaShell );

if ( ReadCLI() )
{
    usage();
    EndProg(1);
}
my $Err=$G_ErrorCounter;
## Read Configuration File (After it was build by the Pvvm read configuration script) ###
my %G_SysConfig=ReadConfig($G_CLIParams{Conf});
unless ( $Err == $G_ErrorCounter )
{
    EndProg(1,"Error - No Configuration Information skip this script.");
}
## Read csv file ###
unless ( GetMergeTool() )
{
    EndProg(1,"\n---    Exit Script with Errors ----");
}

#####    Debug   ########
WrLog("-- Debug The following parametrs found at system config file:");
foreach ( keys(%G_SysConfig) )
{
   WrLog( "- $_  -> $G_SysConfig{$_}");
}

$Err=$G_ErrorCounter;
my %G_RulsList=ReadCsv($G_CLIParams{Rule},$G_CLIParams{Unit},$G_CLIParams{Platform},\%G_SysConfig);
unless ( $Err == $G_ErrorCounter )
{
    EndProg(1,"Error - Fail to get File Configuration information. skip this script");
}
while ( my ($File,$Rules) = each(%G_RulsList) )
{
     unless ( $File =~ s/^([^:]+):// )
     {
     	WrLog("Error - empty file type at csv file. or corupted csv file. skip file configuration",
     	      "      + Full File name \"$File\"");
     	next ;
     }
     my $FileType=$1;
     unless ( defined $FileEdit{$FileType} )
     {
     	WrLog("Error\tUnknown File type \"$FileType\" skip configuration of $File");
     	next;
     }
     ## WrLog("-- Debug (Before) Rule: $Rules");
     ##$Rules =~ s/([^\\])\\([^\\])/\1\\\\\2/g ;
     $Rules =~ s/\"\"/\\\"/g ;
     ## WrLog("-- Debug Rule: $Rules");
     ## unless ( eval ("$FileEdit{$FileType}(\"$Rules\",\"\$File\")") )
     if ( $FileEdit{$FileType}->($Rules,$File) )
     {
     	    WrLog("Error to set \"$FileType\" record at merge tool configuration file ($File).");
     	    $G_ErrorCounter++;
     }
}
## Config Systems ##

WrLog("--Debug csv MergeToolLines:",@G_MergeTool,"\n\n--");
my $MergeFile="/tmp/SetPvvm.csv";
my $MergeLog="/tmp/SetPvvm.log";
if ( WriteFile($MergeFile,@G_MergeTool) )
{
   EndProg(1,"Error - Fail to write setup csv file ($MergeFile)");
}
my $Cmd=GetMergeTool();
$Cmd .= " $MergeFile $MergeLog";
$G_ErrorCounter += RunCmds($Cmd);
if ( $G_ErrorCounter )
{
   my @Display=ReadFile($MergeLog);
   WrLog("Error - merge Result:",@Display,"----------------------------\n\n");
} else
{
    ## RunCmds("rm -f $MergeFile");
}

my $ErrMessage= $G_ErrorCounter ? "Error Script Finish with Errors. see Log File \"$G_CLIParams{LogFile}\"" :
		" --####  Finish  SuccessFuly  ####--" ;
EndProg($G_ErrorCounter,$ErrMessage);