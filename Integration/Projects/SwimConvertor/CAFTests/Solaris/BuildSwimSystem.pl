#!/usr/local/bin/perl

##############################################################################
# Template Script.
# for use at solaris replace the first line with:
# #!/usr/local/bin/perl
#
# for use before CSPBase Installation (at Linux) change the first line to:
# #!/usr/bin/perl
##############################################################################

use strict;
use XML::LibXML ;
#########################################################
#  Global variables
#########################################################

my $G_ErrorCounter=0;
my %G_CLIParams=(  LogFile  => "-" ,
				   SysDir	=> "/var/cti/data/swim/systems" ,
				   KitDir	=> "/var/cti/data/swim/kits" );
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

sub ReadConfiguration #$FileName return %Conf
{
	my $FileName=shift;
	my @FData=ReadFile($FileName);
	my %Result;
	foreach my $Line ( @FData ) 
	{
		####  Skip Remarks
		$Line =~ /^\s*#/ and next;
		#### Update List Parameters  ##
		if ( $Line =~ /(.+)_(\d+)=(.+)/ ) 
		{
			my $ParamBase=$1;
			my $ParamIndex=$2;
			$ParamIndex--;
			my $ParaVal=$3;
			$ParamBase =~ /(.+)(Name|IP|Host)/ or next;
			my ($Unit,$PType)=($1,$2);
			exists $Result{$Unit} or $Result{$Unit}=[];
			exists $Result{$Unit}->[$ParamIndex] or $Result{$Unit}->[$ParamIndex]=[];
			$Result{$Unit}->[$ParamIndex]->[$PType eq "IP" ? 1 : 0]=$ParaVal;
		} elsif ( $Line =~ /(.+?)=(.+)/ ) 
		{
			$Result{$1}=$2;
		}
	}
	return %Result;
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

my %UnitMap=ReadUnitMap($G_CLIParams{Map});
my %Conf=ReadConfiguration($G_CLIParams{Conf});
### Create system folders
$G_ErrorCounter += RunCmds("mkdir -p $G_CLIParams{SysDir}/$Conf{SysName}",
						   "chmod -R 777 $G_CLIParams{SysDir}/$Conf{SysName}");

#####  Create Unit Group Xml 
my $Root=XML::LibXML::Element->new("UnitGroup");
my $XmlObj=XML::LibXML::Document->createDocument("1.0","UTF-8");
while ( my ($UnitType,$Instances) = each(%Conf) ) 
{
	ref($Instances) or next;
	$UnitType =~ /Balanc/i and next;
	unless ( exists $UnitMap{$UnitType} ) 
	{
		WrLog("Error - unsupportd Unit Type \"$UnitType\". all Units of this kind will be ignored");
		$G_ErrorCounter++;
		next;
	}
	my $UnitGrp=$Root->appendChild(XML::LibXML::Element->new("Physical"));
	$UnitGrp->setAttribute("GroupName",$UnitMap{$UnitType}->{GroupName});
	foreach my $HostParams (@$Instances) 
	{
		my $UInst=$UnitGrp->appendChild(XML::LibXML::Element->new("UnitInstance"));
		$UInst->setAttribute("Hostname",$HostParams->[0]);
		$UInst->setAttribute("Mngname",$HostParams->[0]);
		$UInst->setAttribute("DataIp",$HostParams->[1]);
		$UInst->setAttribute("MngIp",$HostParams->[1]);
		$HostParams->[0] =~ /^(.+?)(\.|$)/;
		$UInst->setAttribute("UnitName",$1);
		$UInst=$UInst->appendChild(XML::LibXML::Element->new("Connection"));
		$UInst->setAttribute("Hostname",$HostParams->[0]);
		$UInst->setAttribute("Hostname",$HostParams->[1]);
		$UInst->setAttribute("Type","Data");
	}
}
$XmlObj->setDocumentElement($Root);
unless ( $G_ErrorCounter ) 
{
	WrLog("Info - Create UnitGroup at system $Conf{SysName}");
	$XmlObj->toFile("$G_CLIParams{SysDir}/$Conf{SysName}/UnitGroup.xml",1);
	my $TmpDir=$Conf{SysType};
	$G_ErrorCounter += RunCmds("cp -p $G_CLIParams{KitDir}/CreateSystem/$TmpDir/*UAF.xml $G_CLIParams{SysDir}/$Conf{SysName}");
	######   Update the Balancers Nodes   ###
	my @BalancerList;
	my $Xpath;
	my $BalancerIndx = $Conf{Balancer};
	foreach my $BArray ( @$BalancerIndx ) 
	{
		my %BalancerRec={};
		if ( $BArray->[0] =~ /^[\d\.]+$/ )
		{
			$BalancerRec{IP}=$BArray->[0];
			$Xpath="//Physical/UnitInstance[\@DataIp=\"$BArray->[0]\"]/\@UnitName";
			$BalancerRec{Name}=$XmlObj->find($Xpath);
		} else 
		{
			$BalancerRec{Name}=$BArray->[0];
			$Xpath="//Physical/UnitInstance[\@UnitName=\"$BArray->[0]\"]/\@DataIp";
			$BalancerRec{IP}=$XmlObj->find($Xpath);
		}
		push(@BalancerList,\%BalancerRec);
	}
	opendir RDIR,"$G_CLIParams{SysDir}/$Conf{SysName}";
	my @FList=readdir(RDIR);
	close RDIR;
	foreach my $UafFile ( grep(/UAF.xml/i,@FList) ) 
	{
		$XmlObj=XML::LibXML->new()->parse_file("$G_CLIParams{SysDir}/$Conf{SysName}/$UafFile");
		my @Nodes=$XmlObj->findnodes("//Component/OnlyOn");
		WrLog(sprintf("Info - Update Balancer Info at $UafFile %d XmlNodes",$#Nodes+1));
		####  Update all in Install Only Components .....   ####
		foreach my $TmpNode ( @Nodes ) 
		{
				foreach my $BalancerNode (@BalancerList) 
				{
					$TmpNode->appendTextChild("UnitName",$BalancerNode->{Name});
				}
		}
		######   Update all balancers IP Value Parametes   ####
		@Nodes=$XmlObj->findnodes("//Value");
		my @BIPList;
		foreach my $BREc ( @BalancerList )
		{
		   push(@BIPList,$BREc->{IP});
		}
		
		foreach my $TmpNode ( @Nodes ) 
		{
			$TmpNode->textContent() =~ /#BalancerIP(\d?)#/ or next;
			
			my $TmpNumb=$1;
			my $BRec;
			my $BNode=XML::LibXML::Element->new("Value");
			if ( $TmpNumb )
			{
			   $BRec=exists($BalancerList[$TmpNumb-1]) ? $BalancerList[$TmpNumb-1] : $BalancerList[0];
			   $BNode->appendTextNode($BRec->{IP});
			} else 
			{
			   $BNode->appendTextNode(join(',',@BIPList));
			}
			$TmpNode->replaceNode($BNode);
		}
		my $Str=$XmlObj->toString();
		$Str =~ s/>[\s\n]+</></g;
		my $TmpObj=XML::LibXML->new()->parse_string($Str);
		$TmpObj->toFile("$G_CLIParams{SysDir}/$Conf{SysName}/$UafFile",1);
	}
}

my $ErrMessage= $G_ErrorCounter ? "Finish with ERRORS see Log File $G_CLIParams{LogFile}" :
		"Finish Successfully :-)";
EndProg($G_ErrorCounter,$ErrMessage);