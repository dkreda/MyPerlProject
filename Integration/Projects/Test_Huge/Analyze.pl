#!/usr/bin/perl

##############################################################################
# Template Script.
# for use at solaris replace the first line with:
# #!/usr/local/bin/perl
#
# for use before CSPBase Installation (at Linux) change the first line to:
# #!/usr/bin/perl
##############################################################################

use strict;
#########################################################
#  Global variables
#########################################################

my $G_ErrorCounter=0;
my %G_CLIParams=(  LogFile  => "-" ,
					Top		=> 30 ,
					Gap		=> 1000000 );
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
   -e $File or $G_ErrorCounter++,WrLog("Error - File \"$File\" not exist !"),return;
   WrLog("Info\tReading File $File");
   open INPUT,"< $File";
   my $Err=$?;
   my @Result=<INPUT>;
   $Err += $?;
   close INPUT ;
   $Err += $?;
   $Err and $G_ErrorCounter++,WrLog("Error\tduring File reading error occurred."),return;
   chomp(@Result);
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
   my @DArr=localtime();
   -e $OrigFile or $G_ErrorCounter++,WrLog("Error\tFail to backup file $OrigFile. file Not exists."),return;
   my $Suffix="Backup_";
   $OrigFile =~ /[^\/\\]+$/ ;
   my $JustFile=$1 ;
   $BackFile = $BackFile ? "$BackFile/$JustFile" : 
   sprintf("$OrigFile.$Suffix%4d_%02d_%02d_%02d%02d%02d",$DArr[5]+1900,$DArr[4]+1,$DArr[3],$DArr[2],$DArr[1],$DArr[0]);
   ### Make sure there is no duplicate backup Files ####
   for ( my $i=0 ; -e $BackFile ; $i++ )
   {
		$BackFile =~ s/\.\d+$/.$i/ ;
   }
   WrLog ("Info\tBackup File $JustFile ...");
   RunCmds("perl -MExtUtils::Command -e mv $OrigFile $BackFile") or return $BackFile;
   $G_ErrorCounter++;
   WrLog("Eroor\tFail to Backup File $OrigFile");
   return ;
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
   -e $TmpArray[0] or return WriteFile($TmpArray[0],@Lines) ;
   my $Backup=BackupFile(@TmpArray);
   $Backup or WrLog("Error\tFail to Backup $TmpArray[0] ."),return 1;
   WrLog("Info\tRewriting file $TmpArray[0].");
   if ( WriteFile($TmpArray[0],@Lines) )
   {
		WrLog("Error\tFail to write file $TmpArray[0]");
		if ( -e $Backup )
		{
			WrLog("Info\tRestoring the Original file $TmpArray[0]");
			$G_ErrorCounter += RunCmds("perl -MExtUtils::Command -e mv $Backup $TmpArray[0]");
			return 1;
		}
    } else
    {
		WrLog("Note:\tTo restore the file use $Backup\n");
	}
	return 0;
}

sub GetTop # \%List,$Size
{
	my $List=shift;
	my $Size=shift;
	my $Total=keys(%$List);
	my $Counter=0;
	my (@Result,@DArr);
	while ( my ( $KeyName, $HitCount ) = each (%$List) )
	{
		$Counter++;
		$Counter % $G_CLIParams{Gap} or @DArr=localtime() , WrLog(sprintf("%02d:%02d:%02d - Analyzed %6.2f% (%d)",
																$DArr[2],$DArr[1],$DArr[0],$Counter/$Total * 100,$Counter));
		if ( @Result < $Size or $HitCount > $List->{$Result[-1]} )
		{
			#### Find Location of new Top Record  #
			my $First=0;
			my $Last=$#Result;
			my $Pos=-1;
			#### Search Position ####
			##  WrLog("Info - Going to start Loop search $TotalRec ....");
			my $LastState="No Loop" ;
			while ( $Last > $First )
			{
				$Pos = int(($Last + $First ) / 2 );
				if (  0 + $List->{$Result[$Pos]}  > 0 + $HitCount )
				{
					$LastState="Array[$Pos]= $List->{$Result[$Pos]} > $HitCount";
					$First = $Pos > $First ? $Pos : $Last;
					$LastState .= " ($First,$Pos,$Last)";
				} elsif ( 0 + $List->{$Result[$Pos]}  < 0 + $HitCount )
				{
					$LastState="Array[$Pos]= $List->{$Result[$Pos]} < $HitCount";
					$Last=$Pos;
					$LastState .= " ($First,$Pos,$Last)";
				} else 
				{
					$LastState="Array[$Pos]= $List->{$Result[$Pos]} == $HitCount ($First , $Pos , $Last )";
					last ;
				}
				$Pos = int(($Last + $First ) / 2 );
			}
			####  Update the Array 
			$G_CLIParams{D} and WrLog("Debug - Finish Search $LastState");
			if ( $Pos <= 0 )
			{
				if ( @Result < $Size )
				{			
					unshift(@Result,$KeyName) ;
				} else 
				{
					@Result=($KeyName,@Result[0..($#Result-1)]) ;
				}
			} elsif ( $Pos >= $#Result )
			{
				if ( @Result < $Size )
				{			
					push(@Result ,$KeyName ) ; 
				} else
				{
					$Result[-1]=$KeyName ;
				}
			} else
			{
				my $EndOfSlice = @Result < $Size  ? $#Result : $Size -1 ;
				@Result=(@Result[0..($Pos-1)],$KeyName,@Result[$Pos..$EndOfSlice]);
			}
			if ( $G_CLIParams{D} )
			{
				my @DMess=("Debug - New Position:" );
				for ( my $i=0 ; $i < @Result ; $i++ )
				{
					push(@DMess,sprintf("%2d (%4d) $Result[$i] ",$i,$List->{$Result[$i]}));
				}
				WrLog("",@DMess);
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

my (%DupIps,@FastestSite,$TotalIter,$TotalRec,%ProcCount,%ColumnPos,$Line,%Mem,%ClientRec);
my @MaxLoad = ( 0,[] );
my @SlowestSite = ( 0 , [] ) ;
=comment
my %TableColumns =(     NODE_ID                =  1 ,# IP Address of the HPI node that handles the transaction
                        MSISDN                 =  2 ,# Mobile Subscriber ISDN Number
                        TRANSACTION_URL        =  3 ,# Host name or address and the relative path
                        RESPONSE_CODE          =  4 ,# HTTP Response code
                        START_TIME             =  5 ,# Start time of the transaction
                        END_TIME               =  6 ,# End time of the transaction
                        RESPONSE_ORIG_SIZE     =  7 ,# Response original size.
                        DOWNLOAD_DATA_SIZE     =  8 ,# Size of the HTTP response sent to client, without headers
                        SRC_IP                 =  9 ,# Source IP address of the transaction
                        ORIG_DST_IP            = 10 ,# Original destination IP address of the transaction (as it came from client)
                        USED_DST_IP            = 11 ,# Destination IP address of the transaction after URL DNS resolving (if no DNS -> ORIG_DST_IP)
                        SGSN_IP                = 12 ,# IP address of the SGSN handling the transaction (from RADIUS start)
                        ACC_SESSION_ID         = 13 ,# Accounting session identifier (from RADIUS start)
                        IMEI                   = 14 ,# Client device International Mobile Equipment Identity.
                        USER_AGENT             = 15 ,# The user agent of the request
                        COMPRESSION_LEVEL      = 16 ,# Compression Level of the transaction 1-5
                        CONTENT_TYPE           = 17 ,# HTTP response MIME type
                        UPSTREAM_SIZE          = 18 ,# Size of the request data sent from the client side.
                        DOWNSTERAM_SIZE        = 19 ,# Size of the response data on the RAN side
                        OPTIMIZATION_FLAG      = 20 ,# Was optimization applied on response?
                        CA_FLAG                = 21 ,# Was content adaptation applied on response?
                        CC_FLAG                = 22 ,# Was content control applied on response?
                        CC_BLOCKED             = 23 ,# The action taken by the content control engine on the request
                        CC_REASON              = 24 ,# Reason for the CC block
                        CC_CATEGORY            = 25 ,# The category for the CC block
                        INITIAL_BEARER         = 26 ,# Original network bearer (from RADIUS start)
                        NETWORK_BEARER         = 27 ,# Discovered network bearer
                        APN_IP                 = 28 ,# IP address of the APN used for transaction (from RADIUS start)
                        POC_HIT                = 29 ,# Was the request served from post optimization cache
                        ORIGINAL_REQUEST_HOST  = 30 ,# Video top level domain (in case part of a pre-configured list of websites
                        ORG_CONTENT_LENGTH     = 31 ,# Video content length before compression
                        CONTENT_LENGTH         = 32 ,# Video content length after compression
                        MD5_STRING             = 33 ,# Video identifier in case video was requested from the beginning
                        SEEK_MD5_STRING        = 34 ,# Video identifier in case video was requested from the middle
                        BITRATE                = 35 ,# Average video bitrate
                        IS_BUFFER_LIMITING     = 36 ,# Is buffer tuning activated
                        IS_VIDEO_FROM_CACHE    = 37 ,# Is the video served from the cache
                        IS_VIDEO_SEEK_REQUEST  = 38 ,# Is the video requested from the middle
                        AUDIO_CODEC            = 39 ,# What is the audio encoding
                        VIDEO_CODEC            = 40 ,# What is the video encoding
                        MEDIA_CONTAINER        = 41 ,# What is the video file format
					); 

=cut
$G_ErrorCounter += (! open (CSVHADLE,$G_CLIParams{csv}));
$G_ErrorCounter += $? ;
$G_ErrorCounter and EndProg($G_ErrorCounter,"Fail to open $G_CLIParams{csv}");
WrLog("Info - Reading $G_CLIParams{csv}");
while ( $Line =  <CSVHADLE> )
{
	chomp($Line);
	my @Colums=split(/,/,$Line);
	### First Line should be title
	unless ( $TotalRec )
	{
		for ( my $Indx=$#Colums ; $Indx >= 0 ; $Indx-- )
		{
			$ColumnPos{$Colums[$Indx]}=$Indx;
			# WrLog("Debug - Parssing Column $Indx ($Colums[$Indx])");
		}
		$TotalRec++;
		next ;
	}
	$TotalRec++;
	$Colums[$ColumnPos{URL}] =~ /^(\S+?):\/\/(.+?)(\/|$)/ or WrLog("Error - Line $TotalRec Illegle URL:\"$Colums[$ColumnPos{URL}]"),next;
	my ($Protocol,$DnsName)=($1,$2);
	## WrLog("Debug  -  $Colums[$ColumnPos{URL}]    :    $Protocol,$DnsName");
	exists $ProcCount{$Protocol} or $ProcCount{$Protocol} = [0,0] ;
	$ProcCount{$Protocol}->[0]++;
	$ProcCount{$Protocol}->[1] += $Colums[$ColumnPos{"Iteration Count"}] ;
	$Colums[$ColumnPos{URL}] =~ s/.+?:\/\/// or next;
	$Mem{$Colums[$ColumnPos{URL}]}++;
	my $ClientNum=keys(%ClientRec);
	$ClientNum < 15000000 and $ClientRec{$Colums[$ColumnPos{IP}]}++;
	## WrLog("Sebug -  Update  $Colums[$ColumnPos{URL}]");
	if ( @FastestSite and $Colums[$ColumnPos{"time Load"}] >= $FastestSite[0] )
	{
		$Colums[$ColumnPos{"time Load"}] == $FastestSite[0] and push(@{$FastestSite[1]},$Colums[$ColumnPos{URL}]);
	} else
	{
		@FastestSite=[$Colums[$ColumnPos{"time Load"}],$Colums[$ColumnPos{URL}]];
	}
	#my $UrlNum=keys(%Mem);
	#my $ClientNum=keys(%ClientRec);
	#my ($UrlNum,$ClientNum)=(keys(%Mem),keys(%ClientRec));
	#$UrlNum > 250000 and (($UrlNum % 1000) or WrLog(sprintf("Warning - Url Hash has more than %d Size",$UrlNum)));
	#$ClientNum > 750000 and (($ClientNum % 10000) or WrLog(sprintf("Warning - Client Hash has more than %d Size",$ClientNum)));
	$TotalRec % $G_CLIParams{Gap} and next ;
	my $MessageStr="$TotalRec";
	1 while ( $MessageStr =~ s/(\d)(\d{3})(\D|$)/$1,$2$3/ ) ;
	WrLog(sprintf("Info  - Parrsed till now %12s Records/Lines",$MessageStr));
}
close (CSVHADLE);
my @DArr=localtime() ;
WrLog(sprintf("Info  - %02d:%02d:%02d - Finsh Parse start Analyze",$DArr[2],$DArr[1],$DArr[0]),
		"\tFind top $G_CLIParams{Top} Visited sites:");

my @TopVisite=GetTop(\%Mem,$G_CLIParams{Top});

my @DMess=("List of Top $G_CLIParams{Top} Visited sites :");
for ( my $i=0 ; $i < @TopVisite ; $i++ )
{
	push(@DMess,sprintf("%2d (%4d) $TopVisite[$i] ",$i,$Mem{$TopVisite[$i]}));
}
WrLog("",@DMess,"");

@TopVisite=GetTop(\%ClientRec,$G_CLIParams{Top});

@DMess=("List of Top $G_CLIParams{Top} load Users :");
for ( my $i=0 ; $i < @TopVisite ; $i++ )
{
	push(@DMess,sprintf("%2d (%4d) $TopVisite[$i] ",$i,$ClientRec{$TopVisite[$i]}));
}
WrLog("",@DMess,"");


my $ErrMessage= $G_ErrorCounter ? "Finish with ERRORS see Log File $G_CLIParams{LogFile}" :
		"Finish Successfully :-)";
EndProg($G_ErrorCounter,$ErrMessage);