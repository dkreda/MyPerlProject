#!/usr/cti/apps/CSPbase/Perl/bin/perl
#####################################################################
# This Scripts Update scdb as follow:
# 1. merge template (VW Service ) with scdb
# 2. Add MMGs Units (MMSGW,Proxy and NDU-WHC) to scdb
# 3. Generate Unit Group and distribute UnitGroups ....
#####################################################################
use strict;
use XML::LibXML;
#########################################################
#  Global variables
#########################################################

my $G_ErrorCounter=0;
my %G_CLIParams=(	LogFile  	=> "-" ,
					SwimFolders	=> "/var/cti/data/swim/systems",  ## This Parameter may be deleted !
					TemplateFolder	=> "/tmp" ,
					ScdbBin	=> "/usr/cti/apps/scdb/bin" ,
					ScdbCLi	=>	"/usr/cti/apps/scdb/bin/scdbCli.sh" );
					
my $G_ScdbFile;    ## ="/opt/CMVT/scdb/data/scdb.xml";
my %G_EnvParams;
my @G_RollBackList=();
my @G_FileHandle=();

sub usage
{
    print "$0 [-LogFile FileName]\n";
    print "$0 -SysName \"System Name\" -PVVM (insight4|insight3) (-MainSite|-NonMain|-DCSite|-Embeded) -Service (MMG,VI,WHC etc) -UnitGroup FullPath to UnitGroup File\n";
	print "oooo   TargetSys = SysName  , SwimUnitsName (sysname where can be find the new units to add)\n" ;
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

sub ReadFile
###############################################################################
#
# Input:	$FileName
#
# Return:	@Lines - Content of the file
#
# Description: Read the file and return the array @lines - each line is 
#		a record at the array. if an error ocured @lines will be
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
   	WrLog("Error\tduring File reading error occcurred.");
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

sub WriteFile 
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

sub UpdateFile 
###############################################################################
#
# Input:	$FileName,@Content
#
# Return:	0 - for O.K , != for errors
#
# Description: Write the @Content Lines into $FileName (Backup the file).
#
###############################################################################
{
   my $FileName=shift;
   my @Lines=@_;
   my $Backup=BackupFile($FileName);
   my $Err=0;
   
   unless ( $Backup )
   {
       	WrLog("Error\tFail to Backup $FileName .");
 	return 1;  	    
   }
   WrLog("Info\tRewriting file $FileName.");
   $Err += WriteFile($FileName,@Lines) ;
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

sub CliCmdBuilder #  \%UnitRec,
{
    my $ScdbVer=$G_EnvParams{ScdbVersion};
    ## my $CmdName=shift;
    my $UnitRecP=shift;
    my %AttrMap=("System"	=> $$UnitRecP{SysName} ,
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
     my %Scdb5_0 = (addUnit	=> ["add UnitInstance","Object","UnitName","MacAddress","ManualInactive"] ,
    		   addConn	=> ["add Connection","Object","UnitName","ConnectionType","IP","Hostname"],
    		   retrieve	=> ["retrieve UnitInstance","Object","UnitName"] ,
    		   "Delete"	=> ["delete UnitInstance","Object","UnitName"] ,
    		   updateUnit	=> ["update UnitInstance","Object","UnitName","NewUnitName","MacAddress","ManualInactive"] ,
    		   updateConn	=> ["update Connection","Object","UnitName","newHostname","Type","IP","Hostname"] );
    		   
	### SCDB 5.0.0.0 (DOC-0-049-117) - SCDB 5.2.0.0 (DOC-0-053-433) ###    		   
     my %Scdb5_1 = (addUnit	=> ["add UnitInstance","Object","UnitName","MacAddress","ManualInactive"] ,
    		   addConn	=> ["add Connection","Object","UnitName","ConnectionType","IP","Hostname"],
    		   retrieve	=> ["retrieve UnitInstance","Object","UnitName"] ,
    		   "Delete"	=> ["delete UnitInstance","Object","UnitName"] ,
    		   updateUnit	=> ["update UnitInstance","Object","UnitName","NewUnitName","MacAddress","ManualInactive"] ,
    		   updateConn	=> ["update Connection","Object","UnitName","newHostname","Type","IP","Hostname"] );
			   
	### SCDB 5.0.0.0 (DOC-0-049-117) - SCDB 5.2.0.0 (DOC-0-053-433) ###    		   
     my %Scdb5_2 = (addUnit	=> ["add UnitInstance","Object","UnitName","MacAddress","ManualInactive"] ,
    		   addConn	=> ["add Connection","Object","UnitName","ConnectionType","IP","Hostname"],
    		   retrieve	=> ["retrieve UnitInstance","Object","UnitName"] ,
    		   "Delete"	=> ["delete UnitInstance","Object","UnitName"] ,
    		   updateUnit	=> ["update UnitInstance","Object","UnitName","NewUnitName","MacAddress","ManualInactive"] ,
    		   updateConn	=> ["update Connection","Object","UnitName","newHostname","Type","IP","Hostname"] );

	### SCDB 5.2.2.0 (DOC-0-050-934) - SCDB 5.4.0.1 (DOC-0-082-692) ###    		   
     my %Scdb5_2_2_0 = (addUnit	=> ["add UnitInstance","Object","UnitName","MacAddress","ManualInactive"] ,
    		   addConn	=> ["add Connection","Object","UnitName","Type","IP","Hostname"],
    		   retrieve	=> ["retrieve UnitInstance","Object","UnitName"] ,
    		   "Delete"	=> ["delete UnitInstance","Object","UnitName"] ,
    		   updateUnit	=> ["update UnitInstance","Object","UnitName","NewUnitName","MacAddress","ManualInactive"] ,
    		   updateConn	=> ["update Connection","Object","UnitName","newHostname","Type","IP","Hostname"] );		   
    
    ### SCDB 5.2.2.0 (DOC-0-050-934) - SCDB 5.4.0.1 (DOC-0-082-692) ###    		   
     my %Scdb5_3 = (addUnit	=> ["add UnitInstance","Object","UnitName","MacAddress","ManualInactive"] ,
    		   addConn	=> ["add Connection","Object","UnitName","Type","IP","Hostname"],
    		   retrieve	=> ["retrieve UnitInstance","Object","UnitName"] ,
    		   "Delete"	=> ["delete UnitInstance","Object","UnitName"] ,
    		   updateUnit	=> ["update UnitInstance","Object","UnitName","NewUnitName","MacAddress","ManualInactive"] ,
    		   updateConn	=> ["update Connection","Object","UnitName","newHostname","Type","IP","Hostname"] );
	
    ### SCDB 5.2.2.0 (DOC-0-050-934) - SCDB 5.4.0.1 (DOC-0-082-692) ###    		   
     my %Scdb5_4 = (addUnit	=> ["add UnitInstance","Object","UnitName","MacAddress","ManualInactive"] ,
    		   addConn	=> ["add Connection","Object","UnitName","Type","IP","Hostname"],
    		   retrieve	=> ["retrieve UnitInstance","Object","UnitName"] ,
    		   "Delete"	=> ["delete UnitInstance","Object","UnitName"] ,
    		   updateUnit	=> ["update UnitInstance","Object","UnitName","NewUnitName","MacAddress","ManualInactive"] ,
    		   updateConn	=> ["update Connection","Object","UnitName","newHostname","Type","IP","Hostname"] );
			   
    ### SCDB 5.5 (DOC-0-075-938)   		   
    my %Scdb5_5 = (addUnit	=> ["add UnitInstance","Object","System","UnitName","MacAddress","ManualInactive"] ,
    		   addConn	=> ["add Connection","Object","System","UnitName","Type","IP","Hostname"],
    		   retrieve	=> ["retrieve UnitInstance","Object","System","UnitName"] ,
    		   "Delete"	=> ["delete UnitInstance","Object","System","UnitName"] ,
    		   updateUnit	=> ["update UnitInstance","Object","System","UnitName","NewUnitName","MacAddress","ManualInactive"] ,
    		   updateConn	=> ["update Connection","Object","System","UnitName","newHostname","Type","IP","Hostname"] );
    
    ### SCDB 5.6.0.0 (DOC-0-090-359)   		   
    my %Scdb5_6 = (addUnit	=> ["add UnitInstance","Object","System","UnitName","MacAddress","ManualInactive"] ,
    		   addConn	=> ["add Connection","Object","System","UnitName","Type","IP","Hostname"],
    		   retrieve	=> ["retrieve UnitInstance","Object","System","UnitName"] ,
    		   "Delete"	=> ["delete UnitInstance","Object","System","UnitName"] ,
    		   updateUnit	=> ["update UnitInstance","Object","System","UnitName","NewUnitName","MacAddress","ManualInactive"] ,
    		   updateConn	=> ["update Connection","Object","System","UnitName","newHostname","Type","IP","Hostname"] );	
    
    ###SCDB5.6.1.1(DOC-0-097-709)SCDB5.6.2.0(DOC-0-099-915)SCDB5.6.3.0(DOC-0-102-051)SCDB6.0.0.0(DOC-0-099-921)SCDB6.1.0.0(DOC-0-111-348)	 
    my %Scdb5_6_1_1 = (addUnit	=> ["add UnitInstance","Object","System","UnitName","MacAddress","ManualInactive"] ,
    		   addConn	=> ["add Connection","Object","System","UnitName","Type","IP","Hostname"],
    		   retrieve	=> ["retrieve UnitInstance","Object","System","UnitName"] ,
    		   "Delete"	=> ["delete UnitInstance","Object","System","UnitName"] ,
    		   updateUnit	=> ["update UnitInstance","Object","System","UnitName","NewUnitName","MacAddress","ManualInactive"] ,
    		   updateConn	=> ["update Connection","Object","System","UnitName","newType","Type","IP","Hostname"] );
			   
	###SCDB5.6.1.1(DOC-0-097-709)SCDB5.6.2.0(DOC-0-099-915)SCDB5.6.3.0(DOC-0-102-051)SCDB6.0.0.0(DOC-0-099-921)SCDB6.1.0.0(DOC-0-111-348)	 
    my %Scdb5_6_2_0 = (addUnit	=> ["add UnitInstance","Object","System","UnitName","MacAddress","ManualInactive"] ,
    		   addConn	=> ["add Connection","Object","System","UnitName","Type","IP","Hostname"],
    		   retrieve	=> ["retrieve UnitInstance","Object","System","UnitName"] ,
    		   "Delete"	=> ["delete UnitInstance","Object","System","UnitName"] ,
    		   updateUnit	=> ["update UnitInstance","Object","System","UnitName","NewUnitName","MacAddress","ManualInactive"] ,
    		   updateConn	=> ["update Connection","Object","System","UnitName","newType","Type","IP","Hostname"] );
			   
	###SCDB5.6.1.1(DOC-0-097-709)SCDB5.6.2.0(DOC-0-099-915)SCDB5.6.3.0(DOC-0-102-051)SCDB6.0.0.0(DOC-0-099-921)SCDB6.1.0.0(DOC-0-111-348)	 
    my %Scdb5_6_3_0 = (addUnit	=> ["add UnitInstance","Object","System","UnitName","MacAddress","ManualInactive"] ,
    		   addConn	=> ["add Connection","Object","System","UnitName","Type","IP","Hostname"],
    		   retrieve	=> ["retrieve UnitInstance","Object","System","UnitName"] ,
    		   "Delete"	=> ["delete UnitInstance","Object","System","UnitName"] ,
    		   updateUnit	=> ["update UnitInstance","Object","System","UnitName","NewUnitName","MacAddress","ManualInactive"] ,
    		   updateConn	=> ["update Connection","Object","System","UnitName","newType","Type","IP","Hostname"] );		   
	
    ###SCDB5.6.1.1(DOC-0-097-709)SCDB5.6.2.0(DOC-0-099-915)SCDB5.6.3.0(DOC-0-102-051)SCDB6.0.0.0(DOC-0-099-921)SCDB6.1.0.0(DOC-0-111-348)	 
    my %Scdb6_0 = (addUnit	=> ["add UnitInstance","Object","System","UnitName","MacAddress","ManualInactive"] ,
    		   addConn	=> ["add Connection","Object","System","UnitName","Type","IP","Hostname"],
    		   retrieve	=> ["retrieve UnitInstance","Object","System","UnitName"] ,
    		   "Delete"	=> ["delete UnitInstance","Object","System","UnitName"] ,
    		   updateUnit	=> ["update UnitInstance","Object","System","UnitName","NewUnitName","MacAddress","ManualInactive"] ,
    		   updateConn	=> ["update Connection","Object","System","UnitName","newType","Type","IP","Hostname"] );	

    ###SCDB5.6.1.1(DOC-0-097-709)SCDB5.6.2.0(DOC-0-099-915)SCDB5.6.3.0(DOC-0-102-051)SCDB6.0.0.0(DOC-0-099-921)SCDB6.1.0.0(DOC-0-111-348)	 
    my %Scdb6_1 = (addUnit	=> ["add UnitInstance","Object","System","UnitName","MacAddress","ManualInactive"] ,
    		   addConn	=> ["add Connection","Object","System","UnitName","Type","IP","Hostname"],
    		   retrieve	=> ["retrieve UnitInstance","Object","System","UnitName"] ,
    		   "Delete"	=> ["delete UnitInstance","Object","System","UnitName"] ,
    		   updateUnit	=> ["update UnitInstance","Object","System","UnitName","NewUnitName","MacAddress","ManualInactive"] ,
    		   updateConn	=> ["update Connection","Object","System","UnitName","newType","Type","IP","Hostname"] );			   
			   
    my (%NulScdb,%Result,$ErrFlag);
    		   
    my %ScdbCmds=(None 	    =>   \%NulScdb ,
    		  "5.x.x.x" =>   \%Scdb5_0 ,
    		  "5.1.x.x" =>	 \%Scdb5_1 ,
    		  "5.2.x.x" => 	 \%Scdb5_2 ,
    		  "5.2.2.x" => 	 \%Scdb5_2_2_0 ,
    		  "5.3.x.x" => 	 \%Scdb5_3 , 
			  "5.4.x.x" =>   \%Scdb5_4 ,
    		  "5.5.x.x" =>	 \%Scdb5_5 ,
    		  "5.6.x.x" => 	 \%Scdb5_6 ,
    		  "5.6.1.x" => 	 \%Scdb5_6_1_1 ,
    		  "5.6.2.x" => 	 \%Scdb5_6_2_0 , 
			  "5.6.3.x" => 	 \%Scdb5_6_3_0 ,
    		  "6.x.x.x" => 	 \%Scdb6_0 ,
    		  "6.1.x.x" => 	 \%Scdb6_1 ) ;
    		  
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

sub SyncAttr
###############################################################################
#
# Input:	%Attributes ( Attributes to sync )
#
# Return:
#
# Description:
#
###############################################################################
{
   my %Attributs=@_;
   my $Parser=XML::LibXML->new();
   my $SCDBDoc=$Parser->parse_file($G_ScdbFile);
   my $SCDBRoot=$SCDBDoc->getDocumentElement;
   WrLog("Info - Update SCDB extra attribute Info ...");
   while ( my ($Group,$Rec) = each(%Attributs) )
   {
   	my %TmpAttr=(objectName => $Group );
	### WrLog("Debug - Search Object Elemnt with \"objectName\" = $Group");
   	my $Element=FindElement($SCDBRoot,"Object",%TmpAttr);
	### Ignore Element that not exists
	$Element or next ;
   	%TmpAttr=ReadSection($Rec);
   	while ( my ($AttrName,$AttrValue) = each(%TmpAttr) )
   	{
   	       $Element->setAttribute($AttrName,$AttrValue);
   	       WrLog("Debug - Update $AttrName = $AttrValue");
   	}
   }
   return WriteFile($G_ScdbFile,$SCDBDoc->toString);
}

sub AddUnitsSingle
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
   my @SCDBCmds=();
   my %Attributes;
   my $Err=0;
   while ( my ($UnitIP,$UnitParams) = each(%UnitList) )
   {
   	my %UnitRecord=ReadSection($UnitParams);
 	$UnitRecord{IP}=$UnitIP;
 	$Err += GenAddUnitsToSCDB(%UnitRecord);
 	WrLog("Debug - Update Group \"$UnitRecord{Group}\" ($UnitIP)");
   	defined $Attributes{$UnitRecord{Group}} and next;
   	my @TmpList=();
   	defined $UnitRecord{inventoryMask} and push(@TmpList,"inventoryMask",$UnitRecord{inventoryMask});
   	defined $UnitRecord{display} and push(@TmpList,"display",$UnitRecord{display});
   	$Attributes{$UnitRecord{Group}}=SetSection( @TmpList );
   }
   ###  Update Object Attributes (inventoryMask N/A display 1)  ###
   $Err += SyncAttr(%Attributes);
   return $Err;
}

sub AddUnitsDistribute
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
   my @SCDBCmds=();
   my %Attributes;
   my $Err=0;
   
   while ( my ($UnitIP,$UnitParams) = each(%UnitList) )
   {
   	my %UnitRecord=ReadSection($UnitParams);
	$UnitRecord{IP}=$UnitIP;
	$UnitRecord{SysName}=$G_CLIParams{SysName};
	$Err += GenAddUnitsToSCDB(%UnitRecord);
   	defined $Attributes{$UnitRecord{Group}} and next;
   	$Attributes{$UnitRecord{Group}}=SetSection( ( inventoryMask => $UnitRecord{inventoryMask}, display => $UnitRecord{display} ));
   }
   ###  Update Object Attributes (inventoryMask N/A display 1)  ###
   $Err += SyncAttr(%Attributes);
   return $Err;
}

sub FindElement
###############################################################################
#
# Input:	$RootElement,$ElemntName,%Attributes
#
# Return:       $Elemnt ot Null
#
# Description:  Find the relevant Elemnt by
#
###############################################################################
{
    my $RootElement=shift;
    my $ElemntName=shift;
    my %Attributes=@_;
    my $Result;
    my $Flag;
    foreach my $Object ( $RootElement->getElementsByTagName($ElemntName) )
    {
    	$Flag = 0;  ### Flag =0 Indicates The Elenent Match ###
    	keys(%Attributes);
    	while ( my ($AttrName,$AttrVale) = each (%Attributes) )
    	{
    	   unless ( $Object->getAttribute($AttrName) eq $AttrVale )
    	   {
    	   	$Flag=1;
    	   	last;
    	   } 
    	}
    	$Flag and next ;  ## Flag 1 indicates The Element NOT Match ##
    	$Result=$Object;
    	last;
    }
    return $Result;
}

sub NullCmd
{
   WrLog("Info - @_. Excute Null command.");
   return 0;
}

sub BuildOvoMap
{
   my $StpFile="/opt/CMVT/ICC/tools/STP/stp.pl";
   unless ( -e $StpFile )
   {
   	WrLog("Info - The File \"$StpFile\" is missing.",
   	      "     + if HP OVO is installed on this machine it will not be update with the new Topology.",
   	      "     + login to OVO application and rebuild topolgy manually.");
   	return 0
   }
   WrLog("Info - Update HP OVO Topology");
   return RunCmds($StpFile);
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

sub AddAppToSCDB_IS3
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
    ## my @AppNames=("ftm_audit_unix");
    
    while ( my ($UnitIP,$UnitParams) = each(%UnitList) )
    {
   	my %UnitRecord=ReadSection($UnitParams);
   	my @AppList=split(',',$UnitRecord{AppName});
   	foreach my $App (@AppList)
   	{
   	    my $ScdbCli="su - scdb_user -c \"$G_CLIParams{ScdbBin}/scdbCli.sh retrieve Application Object=$UnitRecord{Object} " .
   	    		"System=$G_CLIParams{SysName} ApplicationName=$App\"";
   	    system($ScdbCli) or next ;
   	    $ScdbCli="su - scdb_user -c \"$G_CLIParams{ScdbBin}/scdbCli.sh add Application Object=$UnitRecord{Object} System=$G_CLIParams{SysName} " .
   	    	    "ApplicationLabel=\"$App\" ApplicationName=\"$App\" ConnectionType=Management ApplicationLevel=Farm  FQDNConcat=false\"";
   	    $G_ErrorCounter += RunCmds($ScdbCli);
   	}
    }
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
    if (($G_EnvParams{ScdbVersion} eq "6.1.x.x") or ($G_EnvParams{ScdbVersion} eq "6.x.x.x"))
    {
        return RunCmds($ScdbCmd . "UnitGroupDistributor all\"", $ScdbCmd . "ScdbFileDistributor all\"");
    }
    else
    {
         return RunCmds($ScdbCmd . "UnitGroupDistributor all\"");
    }
}

sub getUnitListRec
###############################################################################
#
# Input:	%SCDBObj ( The object Return from SCDBFactory ....)
#
# Return:
#
# Description: Group,UnitName,Object
#
###############################################################################
{
   my %SCDBObj=@_;
   my $UnitFile="unitList.txt";
   ## my $XmlVal="xmlValues";
   my $OctFile="UnitsBackup.Oct";
   my @AttrList=("inventoryMask","display");
   
   my $Err=$G_ErrorCounter;
   WrLog("Info - Build Unit List");
   my (%Result,%MapRec,%RevMap);
   my @Content=ReadFile($UnitFile);
   foreach my $Line (@Content)
   {
   	my @Fields=split(/\s+/,$Line);
   	$#Fields >= 1 or next;
   	$MapRec{$Fields[0]}=$Fields[1];
   	$Fields[1] =~ s/Unit/Group/ and $RevMap{$Fields[1]}=$Fields[0] , $MapRec{$Fields[0]} .= " $Fields[1]";
   }
   @Content=ReadFile($OctFile);
   $G_ErrorCounter - $Err and return ;
   foreach my $Line ( @Content )
   {
   	my @Fields=split(/,/,$Line);
   	$#Fields >= 2 or next;
   	defined $MapRec{$Fields[2]} or next ;
   	### we must remove the dotes from the host name - cause IS4 add the system FQDN to the 
   	### end of the host name at file hosts. to prevent from ftm to get unknown host error we 
   	### must remove the dots from the host name !!!
   	$Fields[0] =~ s/\./_/g ;
   	my %TempRec= ( UnitName => $Fields[0] );
   	my @RecFields=split(/\s+/,$MapRec{$Fields[2]});
   	$TempRec{Object}=shift(@RecFields);
   	$TempRec{Group}=shift(@RecFields);
   	while ( $#RecFields >= 0 )
   	{
   	    my $Temp=shift(@RecFields);
   	    $TempRec{$Temp}=shift(@RecFields);
   	}
   	foreach my $AttName (@AttrList)
   	{
   		defined $SCDBObj{$AttName} or next;
   		$TempRec{$AttName}=$SCDBObj{$AttName};
   	}
   	$Result{$Fields[1]}=SetSection(%TempRec);
   }
   return %Result;
}


sub ParseUnitGroup
###############################################################################
#
# Input:	$UnitFile,%SCDBObj ( The object Return from SCDBFactory ....)
#
# Return:
#
# Description: Group,UnitName,Object
#
###############################################################################
{
	## my $SysName=shift;
	my $UnitFile=shift;
	my %SCDBObj=@_;
	## my $UnitFile="$G_CLIParams{SwimFolders}/$SysName/UnitGroup.xml";
	unless ( -e $UnitFile )
	{
		WrLog("Error - could not find file $UnitFile");
		$G_ErrorCounter++;
		return ;
	}
   
   my @AttrList=("inventoryMask","display");
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
			%TempRec = ( UnitName	=> $UName ,
						 Object		=> $UnitType ,
						 Group		=> $GroupName ) ;
			foreach my $AttName (@AttrList)
			{
				exists $SCDBObj{$AttName} or next;
				$TempRec{$AttName}=$SCDBObj{$AttName};
			}
			$Result{$UIP}=SetSection(%TempRec);
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

sub SetTemplateData
###############################################################################
#
# Input:	$SourceFile,$TargetFile,$SytemName
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
    my ($SourceFile,$TargetFile,$SytemName)=@_;
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
	
	### Update Hosting Application .....
	##  Key - The Template Application Name
	##  Value -  ( 1. Scdb Application Ref  , 2. Attr Name )
	my %AppMap = ( "ODS_CALLS"	=> [ "ODS","HostingUnits" ] );
	exists $G_CLIParams{D} and WrLog("Debug - Start Update Special Attributes ...");
	while ( my ( $SAppName,$TVals )= each (%AppMap) )
	{
		@TargetNodes=$SourceXml->findnodes("//Application[\@ApplicationName=\"$SAppName\"]");
		@TargetNodes or next;
		exists $G_CLIParams{D} and WrLog("Debug - Application $SAppName should be updated");
		my $NewVal=$SCDBXml->findvalue(sprintf(q<//Application[@ApplicationName="%s"]/@%s>,$TVals->[0],$TVals->[1]));
		$NewVal or WrLog("Error - scdb Do Not have Application \"$TVals->[0]\". can not update \"$SAppName\" special attributes"),$Err++,next;
		foreach my $Node ( @TargetNodes )
		{
			$Node->setAttribute($TVals->[1],$NewVal);
			exists $G_CLIParams{D} and WrLog("Debug - Update $SAppName with $TVals->[0] = $TVals->[1]");
		}
	}
	$Err += $SourceXml->toFile($TargetFile,1) ? 0 : 1;
	$Err += RunCmds("chmod 666 $TargetFile");
	return $Err;
}

sub PickSystemVars ##@InstalationOp
{
    my @InstalationOp=@_;
    my %Result = ( PvvmType	=> ( $G_CLIParams{PVVM} =~ /InSight4/i ? "insight4" : $G_CLIParams{PVVM} ),
    		   ScdbType	=> $G_CLIParams{Type} );
    
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
    if ( $IntVer >= 60100 )
	{
	   $Result{ScdbVersion}="6.1.x.x";
	} elsif ( $IntVer >= 60000 )
	{
		$Result{ScdbVersion}="6.x.x.x";
	} elsif ( $IntVer >= 50603 )
	{
		$Result{ScdbVersion}="5.6.3.x";
	} elsif ( $IntVer >= 50602 )
	{
		$Result{ScdbVersion}="5.6.2.x";
	} elsif ( $IntVer >= 50601 )
	{
		$Result{ScdbVersion}="5.6.1.x";
	} elsif ( $IntVer >= 50600 )
    {
    	$Result{ScdbVersion}="5.6.x.x";
    } elsif ( $IntVer >= 50500 )
    {
    	$Result{ScdbVersion}="5.5.x.x";
    } elsif ( $IntVer >= 50400 )
	{
		$Result{ScdbVersion}="5.4.x.x";
	}elsif ( $IntVer >= 50300 )
    {
    	$Result{ScdbVersion}="5.3.x.x";
	} elsif ( $IntVer >= 50202 )
    {
    	$Result{ScdbVersion}="5.2.2.x";
    } elsif ( $IntVer >= 50200 )
    {
    	$Result{ScdbVersion}="5.2.x.x";
    } elsif ( $IntVer >= 50100 )
    {
    	$Result{ScdbVersion}="5.1.x.x";
    } elsif ( $IntVer >= 50000 )
    {
    	$Result{ScdbVersion}="5.x.x.x";
    } else { $Result{ScdbVersion}="None"; }
    
    ##  Check SCDB Type  (Distribute or Single ) ###
    WrLog("Info - Check SCDB Type ...");    		       
    unless ( $Result{ScdbType} eq "None" )
    {
    	my @SysNames=`su - scdb_user -c "$G_CLIParams{ScdbBin}/scdbCli.sh get Systems" | grep "Parent Object name"` ;
    	chomp @SysNames;
    	$Result{ScdbType} = $#SysNames > 0 ? "Distribute" : "Single" ;
    	$Result{SystemNames}=\@SysNames;
    	WrLog("Info - Change SCDB type to $Result{ScdbType}");
    }
    ### Resolve Installation Type ###
    WrLog("Info - Resolving Installation Type ...");
    $Result{InstallType}="UnKNown";
    foreach (@InstalationOp)
    {
    	exists $G_CLIParams{$_} and $Result{InstallType}=$_ , last;
    }
    return %Result;
}

sub getServiceMergeFile  #Service
{
	my $Service=shift;
	my %FileList= ( MMG		=> ["Voicewriter_scdb.xml","Voicewriter_scdb_Distribute.xml","Voicewriter_scdb_IS3.xml","Voicewriter_scdb_Distribute_IS3.xml","Voicewriter_scdb.xml","Voicewriter_scdb_Distribute.xml"] ,
					VoiceWriter => ["Voicewriter_scdb.xml","Voicewriter_scdb_Distribute.xml","Voicewriter_scdb_IS3.xml","Voicewriter_scdb_Distribute_IS3.xml","Voicewriter_scdb.xml","Voicewriter_scdb_Distribute.xml"] ,
					WHC		=> ["WHC_scdb.xml","WHC_scdb_Distribute.xml","WHC_scdb_IS3.xml","WHC_scdb_Distribute_IS3.xml","WHC_scdb_IS5.xml","WHC_scdb_Distribute_IS5.xml"] ,
					VM2MMS	=> ["VNM2MMS_scdb.xml","VNM2MMS_scdb.xml","VNM2MMS_scdb.xml","VNM2MMS_scdb.xml","VNM2MMS_scdb.xml","VNM2MMS_scdb.xml"] ,
					VVM		=> ["VVM_scdb.xml","VVM_scdb.xml","VVM_scdb.xml","VVM_scdb.xml","VVM_scdb.xml","VVM_scdb.xml"] ,
					WebInbox => ["Webinbox_scdb.xml","Webinbox_scdb.xml","Webinbox_scdb.xml","Webinbox_scdb.xml","Webinbox_scdb.xml","Webinbox_scdb.xml"] ,
					MTE => ["MTE_scdb.xml","MTE_scdb.xml","MTE_scdb.xml","MTE_scdb.xml","MTE_scdb.xml","MTE_scdb.xml"] );
	unless ( exists $FileList{$Service} )
	{
		WrLog("Error - UnKnown Service Type \"$Service\"",
			  "\t Available Services:");
		foreach my $Tmp ( keys (%FileList) )
		{
			WrLog("\t - $Tmp");
		}
		WrLog("");
		$G_ErrorCounter++;
		return;
	}
	return @{$FileList{$Service}};
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
# Input:
#
# Return:	%ScdbFactory
#
# Description:  Setup Parameers acording to system ...
#
###############################################################################
{
    my $Service=shift;
	my %Result;
    my %InstallType= ( MainSite	=> ["inventoryMask=N/A","display=0"] ,
    		       NonMain	=> ["inventoryMask=N/A","display=0"] ,
    		       DCSite	=> [\&BuildOvoMap,"inventoryMask=N/A","display=1"] ,
    		       Embeded	=> [\&BuildOvoMap,"inventoryMask=N/A","display=1"] );
    my @TemplFileList=getServiceMergeFile($Service);
	@TemplFileList or $G_ErrorCounter++ , return ;
    #  0.AddUnits5.x.x.x, 1.AddUnits5.5.x.x , 2. TemplateFileInsight4 , 3. TemplateFileInsight3  
    my %ScdbTypeRes= (Distribute => [\&AddUnitsDistribute,\&AddUnitsDistribute,$TemplFileList[1],$TemplFileList[3],$TemplFileList[5]] ,
    		      Single	 => [\&AddUnitsSingle,\&AddUnitsDistribute,$TemplFileList[0],$TemplFileList[2],$TemplFileList[4]] );

     
    ## Find scdb File
	

	%G_EnvParams=PickSystemVars(keys %InstallType); 
	$G_EnvParams{ScdbFile}=$G_ScdbFile; ## This just for debug purpose to show in the log where is the scdb file
    #	    0.ScdbMerge , 1.buildTemplate , 2. AddUnits->scdbtype0..1 
    my %ScdbVerRes= ( None => 	   [\&NullCmd,\&NullCmd,\&NullCmd] ,
    		      "5.x.x.x" => [\&NullCmd,\&NullCmd,$ScdbTypeRes{$G_EnvParams{ScdbType}}[0]] ,
    		      "5.1.x.x" => [\&NullCmd,\&NullCmd,$ScdbTypeRes{$G_EnvParams{ScdbType}}[0]] ,
				  "5.2.x.x" => [\&NullCmd,\&NullCmd,$ScdbTypeRes{$G_EnvParams{ScdbType}}[0]] ,
				  "5.2.2.x" => [\&NullCmd,\&NullCmd,$ScdbTypeRes{$G_EnvParams{ScdbType}}[0]] ,
				  "5.3.x.x"	=> [\&NullCmd,\&NullCmd,$ScdbTypeRes{$G_EnvParams{ScdbType}}[0]] ,
    		      "5.4.x.x" => [\&NullCmd,\&NullCmd,$ScdbTypeRes{$G_EnvParams{ScdbType}}[0]] ,
				  "5.5.x.x" => [\&SCDBMerge,\&SetTemplateData,$ScdbTypeRes{$G_EnvParams{ScdbType}}[1]] ,
				  "5.6.x.x" => [\&SCDBMerge,\&SetTemplateData,$ScdbTypeRes{$G_EnvParams{ScdbType}}[1]] ,
				  "5.6.1.x" => [\&SCDBMerge,\&SetTemplateData,$ScdbTypeRes{$G_EnvParams{ScdbType}}[1]] ,
				  "5.6.2.x" => [\&SCDBMerge,\&SetTemplateData,$ScdbTypeRes{$G_EnvParams{ScdbType}}[1]] ,
    		      "5.6.3.x"	=> [\&SCDBMerge,\&SetTemplateData,$ScdbTypeRes{$G_EnvParams{ScdbType}}[1]] ,
				  "6.1.x.x"	=> [\&SCDBMerge,\&SetTemplateData,$ScdbTypeRes{$G_EnvParams{ScdbType}}[1]] ,
				  "6.x.x.x" => [\&SCDBMerge,\&SetTemplateData,$ScdbTypeRes{$G_EnvParams{ScdbType}}[1]] );				  
				  

    # 0.AddApp , 1.TemplateFile->scdbType2..3 , 2. PostInstall		      
    my %ScdbPvvmRes= ( insight4	=>  [\&NullCmd,$ScdbTypeRes{$G_EnvParams{ScdbType}}[2],\&NullCmd],
    		           insight3	=>  [\&AddAppToSCDB_IS3,$ScdbTypeRes{$G_EnvParams{ScdbType}}[3],\&SCDBpostInstall] ,
					   insight5	=>  [\&NullCmd,$ScdbTypeRes{$G_EnvParams{ScdbType}}[4],\&NullCmd] );

    ### Check if Init is O.K ###
    
    my @Message=("Info - System / Envaironment Parameters:" ) ;
    
    foreach my $Param ("PvvmType","ScdbType","InstallType","ScdbVersion","ScdbFile")
    {
    	push(@Message,"\t$Param: $G_EnvParams{$Param}");
    	defined $G_EnvParams{$Param} and next;
    	$G_ErrorCounter++;
    	WrLog("Error - Fail / missing parameter $Param");
    }
    defined $ScdbVerRes{$G_EnvParams{ScdbVersion}}  or $G_ErrorCounter++,WrLog("Err - Unknown ScdbVersion $G_EnvParams{ScdbVersion}") ;
    defined $ScdbPvvmRes{$G_EnvParams{PvvmType}} 	  or $G_ErrorCounter++,WrLog("Err - Unknown Pvvm $G_EnvParams{PvvmType}");
    defined $ScdbTypeRes{$G_EnvParams{ScdbType}} 	  or $G_ErrorCounter++,WrLog("Err - Unknown Scdb type $G_EnvParams{ScdbType}");
    defined $InstallType{$G_EnvParams{InstallType}} or $G_ErrorCounter++,WrLog("Err - Unknown Install Type $G_EnvParams{InstallType}");
    
    if ( $G_ErrorCounter )
    {
    	WrLog("Error - Fail to Init Script. one of the initial parameters is wrong or not supported:" ,
    		@Message);
    	return ;
    }
    push(@Message,"Info - The Following System Exist at SCDB:");
    foreach my $SysName ( @{$G_EnvParams{SystemNames}} )
    {
    	push(@Message,"\t* $SysName");
    }
    WrLog(@Message,'-' x 60,"");
    
    #######     Assign  The Result Factory   ######
 
    $Result{ScdbMerge}=$ScdbVerRes{$G_EnvParams{ScdbVersion}}[0];
    $Result{buildTemplate}=$ScdbVerRes{$G_EnvParams{ScdbVersion}}[1];
    $Result{TemplateFile}=$ScdbPvvmRes{$G_EnvParams{PvvmType}}[1];
    $Result{AddApp}=$ScdbPvvmRes{$G_EnvParams{PvvmType}}[0];
    $Result{AddUnits}=$ScdbVerRes{$G_EnvParams{ScdbVersion}}[2];
    $Result{MergeFile}="/tmp/Template_scdb_system.xml";
    $Result{Generate}=\&ScdbGenerate;
    $Result{Validate}=\&ValidateSCDB; 
	$Result{PvvmType}=$G_EnvParams{PvvmType};
	$Result{InstallType}=$G_EnvParams{InstallType};
    
    ####  SCDb Settings     ###
    my @PostInstallOperation=($ScdbPvvmRes{$G_EnvParams{PvvmType}}[2]);
    my $List=$InstallType{$G_EnvParams{InstallType}};
    foreach my $Iter(@$List)
    {
    	my @Fields=split(/=/,$Iter);
    	if ( $#Fields > 0 )
    	{
    	    $Result{$Fields[0]}= $Fields[1] =~ /\\&/ ? eval($Fields[1]) : $Fields[1];
    	  #  WrLog("Debug - Factory Add Attribute $Fields[0] to configuration ...");
    	} else
    	{
    	    push(@PostInstallOperation,$Iter);
    	  #  WrLog("Debug - Add Post Install operation $Fields[0]");
    	}
    }
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
    my @ParamMust=("SysName","UnitGroup");
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
    foreach my $Name (@ParamMust)
    {
    	defined $G_CLIParams{$Name} and next;
    	WrLog("Error - missing Parameter $Name");
    	$Err++;
    }
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

my ($ScdbBackup,%UnitList,%SCDBObj);
#### Call Factory Builder (Check scdb version and Type (distribute or single) and PVVM Type (IS4/IS3)###
$G_ScdbFile=GetSCDBPath();
$ScdbBackup=BackupFile($G_ScdbFile) or EndProg(1,"Fatal - Fail to Backup scdb");
 push(@G_RollBackList,$ScdbBackup);
 foreach my $ServiceName ( split(/,/,$G_CLIParams{Service} ) )
 {
	%SCDBObj=ScdbFactory($ServiceName);
	WrLog("Info - Start Merge Procedure using template $SCDBObj{TemplateFile}");
	if ( $SCDBObj{buildTemplate}->("$G_CLIParams{TemplateFolder}/$SCDBObj{TemplateFile}",$SCDBObj{MergeFile},$G_CLIParams{SysName}) )
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
exists $SCDBObj{InstallType} or $G_ErrorCounter++;
$G_ErrorCounter and EndProg(1,"Fatal - Fail to Determine which installation Type this machine Requiers");
WrLog("Info - This is $SCDBObj{InstallType} installation add units to scdb");
## Build Unit List using UnitsBackup.Oct  and unitList.txt  ##
## %UnitList=getUnitListRec(%SCDBObj);
%UnitList=ParseUnitGroup($G_CLIParams{UnitGroup},%SCDBObj);
keys(%UnitList) or WrLog("Warning - Empty Unit List. This may be cause configuration Error");
if ( exists $G_CLIParams{D} )
{
	while ( my ($HKey,$HVal) = each(%UnitList) )
	{
		WrLog("Debug - $HKey -> $HVal");
	}
}
## Run AddUnitsToScdb $G_CLIParams{SysName}  ####
WrLog("Info - Add units to scdb ....");
$G_ErrorCounter += $SCDBObj{AddUnits}->(%UnitList);
## Run ScdbEdit ###  No Need alreday in addunits ....

###  ftm_audit_unix  .... ####
WrLog("Info - Add Extra Applications to Unit Groups at SCDB ...");
$G_ErrorCounter += $SCDBObj{AddApp}->(%UnitList);
####  Check Result .....
if ( $SCDBObj{Validate}->() )
{
   WrLog("Error - Fail to Update scdb. Roll Back to old SCDB");
   ##RunCmds("mv -f $ScdbBackup $G_ScdbFile");
   RollBack() and WrLog("Error - FAIL TO RESTORE SOME OF FILES - Pleas check the Log and restore it Manually ...");
   WrLog(@G_RollBackList);
   EndProg(1,"Fatal - SCDB Update failed see Log $G_CLIParams{LogFile}");
}
## Generate + Distribute ####
WrLog("Info - Start Generating Unit group + distribute ...");
$G_ErrorCounter += $SCDBObj{Generate}->();
###  SCDB Post Install ####  Add Units to /etc/hosts
WrLog("Info - Running Post instal (if it is nedded)...");
my $FuncList=$SCDBObj{PostInstall};
foreach my $RunFunc (@$FuncList)
{
   $G_ErrorCounter += $RunFunc->();
}

my $ErrMessage= $G_ErrorCounter ? "E R R O R - script finish with Errors. see $G_CLIParams{LogFile}" :
	"S U C C E S S F U L - Finish" ;
EndProg($G_ErrorCounter,$ErrMessage);