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

sub TimeStr
{
	my @TimeArray=localtime();
	return sprintf("%02d:%02d:%02d",$TimeArray[2],$TimeArray[1],$TimeArray[0]);
}

sub GetTop # \%List,$Size
{
	my $List=shift;
	my $Size=shift;
	my $Debug=shift;
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
			my $Last=@Result;
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
			if ( $Debug )
			{
				WrLog("Before Change $LastState");
				my @Stam;
				map { push(@Stam,"\t$_ > $List->{$_}"); } @Result ;
				WrLog(@Stam,"");
			}
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
			if ( $G_CLIParams{D}  or $Debug )
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

## my (%DupIps,@FastestSite,$TotalIter,$TotalRec,%ProcCount,%ColumnPos,$Line,%Mem,%ClientRec);
my $TotalRec=0;
my @MaxLoad = ( 0,[] );
my @SlowestSite = ( 0 , [] ) ;

my %TableColumns =(     NODE_ID					=> 0 , # IP address of the MSP node handled the transaction
						MSISDN					=> 1 , #Mobile Subscriber ISDN Number
						TRANSACTION_URL			=> 2 , #Host name or address and the relative path
						RESPONSE_CODE			=> 3 , # HTTP Response code
						START_TIME				=> 4 ,# Start time of the transaction
                        END_TIME				=> 5 ,# End time of the transaction
                        RESPONSE_ORIG_SIZE		=> 6 ,# Response original size.
                        DOWNLOAD_DATA_SIZE		=> 7 ,# Size of the HTTP response sent to client, without headers
                        SRC_IP					=> 8  ,# Source IP address of the transaction
                        ORIG_DST_IP				=> 9 ,# Original destination IP address of the transaction (as it came from client)
                        USED_DST_IP				=> 10 ,# Destination IP address of the transaction after URL DNS resolving (if no DNS -> ORIG_DST_IP)
                        SGSN_IP					=> 11 ,# IP address of the SGSN handling the transaction (from RADIUS start)
						ACC_SESSION_ID			=> 12 ,# Accounting session identifier (from RADIUS start)
						IMEI					=> 13 ,# Client device International Mobile Equipment Identity.
                        USER_AGENT				=> 14 ,# The user agent of the request
						COMPRESSION_LVL			=> 15 ,#Compression Level of the transaction 1-5
						CONTENT_TYPE			=> 16 , #HTTP response MIME type
						UPSTREAM_SIZE			=> 17 , #Size of the response data on the internet side
						DOWNSTERAM_SIZE			=> 18 , #Size of the response data on the RAN side
						OPTIMIZATION_FLAG		=> 19 ,
						CA_FLAG					=> 20 ,
						CC_FLAG					=> 21 ,
						CC_BLOCKED				=> 22 ,
						CC_REASON				=> 23 ,
						CC_CATEGORY				=> 24 ,
						INITIAL_BEARER			=> 25 ,
						NETWORK_BEARER			=> 26 ,
						APN_IP					=> 27 ,
						POC_HIT_FLAG			=> 28 ,
						IMSI					=> 29 ,
						ORIGINAL_REQUEST_HOST	=> 30 ,
						ORG_CONTENT_LENGTH		=> 31 ,
						CONTENT_LENGTH			=> 32 ,
						MD5_STRING				=> 33 ,
						ORG_BITRATE				=> 34 ,
						BITRATE					=> 35 ,
						IS_BUFFER_LIMITING		=> 36 ,
						IS_FROM_CACHE			=> 37 ,
						IS_SEEK_REQUEST			=> 38 ,
						AUDIO_CODEC				=> 39 ,
						VIDEO_CODEC				=> 40 ,
						MEDIA_CONTAINER			=> 41 ,
						CACHED_EXTRA_BYTES_LENGTH => 42 ,
						PARENT_MSISDN			=> 43 ,
						SEND_NOTIFY				=> 44 ,
						IS_CACHED				=> 45 ,
						IS_TO_CACHE				=> 46 ,
						TRANSCODING_LEVEL		=> 47 ,
						HTTP_METHOD				=> 48 ,
						NETWORK_RATE			=> 49 ,
						ORG_AUDIO_CODEC			=> 50 ,
						ORG_VIDEO_CODEC			=> 51 ,
						CONTENT_ENCODING_HEADER	=> 52 ,
						TRANSFER_ENCODING_HEADER => 53 ,
						MODIFIED_CONTENT_TYPE	=> 54 ,
						FULL_RESOURCE_CONTENT_LENGTH => 55 ,
						RANGE_REQUEST_HEADER	=> 56 ,
						CACHE_HITS				=> 57 ,
						TOOLBAR_FLAG			=> 58 ,
						HPI_CACHE_PUT_TIME		=> 59 ,
						HITS_TM_GET				=> 60 ,
						TM_IN_TIME				=> 61 ,
						TM_OUT_TIME				=> 62 ,
						MEDIA_HANDLING_TYPE		=> 63 ,
						MEDIA_QUALITY_LEVEL		=> 64 ,
						VIDEO_START_TIME		=> 65 ,
						NUMBER_OF_STALLS		=> 66 ,
						AVERAGE_STALLS_LENGTH	=> 67 ,
						NUMBER_OF_DRA_DECREASES	=> 68 ,
						HPI_INSTANCE			=> 69 ,
						UIDH					=> 70 ,
						WEB_RESPONSE_CODE		=> 71 ,
						WEB_ROUND_TRIP_TIME		=> 72 ,
						CLIENT_ROUND_TRIP_TIME	=> 73 ,
						HTTP_REQUEST_VERSION	=> 74 ,
						HTTP_RESPONSE_VERSION	=> 75 ,
						DNS_RESPONSE_TIME		=> 76 ,
						DOWNLOAD_ORIG_SIZE		=> 77 ,
						IS_FROM_TUNNEL			=> 78 ,
						TOOLBAR_REQUEST_TYPE	=> 79 ,
						TOOLBAR_INSERTION_INDICATION => 80 ,
						TOOLBAR_SOURCE_URL		=> 81 ,
						PROFILE_TEMPLATE		=> 82 ,
						ADDITIONAL_INFO			=> 83 ,
						CLIENT_CONNECTION_TTL	=> 84 ,
						ICL_REASON				=> 85 ,
						MLT_LEVEL_REASON		=> 86 ,
						OT_LEVEL_REASON			=> 87 ,
						DRA_LEVEL_REASON		=> 88,
						ONLINE_DRA_LEVEL_REASON	=> 89 ,
						CELL_ID					=> 90 
					); 

my (%TopDomains,%TopDomainsFilter,%TopDevices,%TopDevicesFilter,%TopApplication,%TopApplicationFilter) ;					

$G_ErrorCounter += open (CSVHADLE,$G_CLIParams{csv}) ? 0:1 ;
$G_ErrorCounter += $? ;
$G_ErrorCounter and EndProg($G_ErrorCounter,"Fail to open $G_CLIParams{csv}");
WrLog("Info - Reading $G_CLIParams{csv}");
while ( my $Line =  <CSVHADLE> )
{
	chomp($Line);
	my @Colums=split(/\t/,$Line);
	
	$TotalRec++;
	## $Colums[$TableColumns{URL}] =~ s/(\S+):\/\/// or WrLog("Error - Line $TotalRec Illegle URL:\"$Colums[$ColumnPos{URL}]"),next;
	unless ( $Colums[$TableColumns{TRANSACTION_URL}] =~ s/(\S+):\/\/// )
	{
		WrLog("Error - Line $TotalRec Illegle URL:\"$Colums[$TableColumns{TRANSACTION_URL}]\" (Column $TableColumns{TRANSACTION_URL})");
		$G_ErrorCounter++;
		WrLog("Debug - Orig Line:",$Line);
		$G_ErrorCounter > 10 or next;
		last;
	}
	
	my $FlagMatch="OK";
	while ( my ($FilterName,$FilterVal) = each(%TopDomainsFilter) )
	{
		$Colums[$TableColumns{$FilterName}] eq $FilterVal and next;
		undef $FlagMatch;
		last;
	}
	$FlagMatch and $TopDomains{$Colums[$TableColumns{TRANSACTION_URL}]}++;
	
	$FlagMatch="OK";
	while ( my ($FilterName,$FilterVal) = each(%TopDevicesFilter) )
	{
		$Colums[$TableColumns{$FilterName}] eq $FilterVal and next;
		undef $FlagMatch;
		last;
	}
	$FlagMatch and $TopDevices{$Colums[$TableColumns{CONTENT_TYPE}]}++;
	
	$FlagMatch="OK";
	while ( my ($FilterName,$FilterVal) = each(%TopApplicationFilter) )
	{
		$Colums[$TableColumns{$FilterName}] eq $FilterVal and next;
		undef $FlagMatch;
		last;
	}
	$FlagMatch and $TopApplication{$Colums[$TableColumns{USER_AGENT}]}++;

	$TotalRec % $G_CLIParams{Gap} and next ;
	my $MessageStr=sprintf("%s Info - parrsed till now %9d) Records/Lines",TimeStr(),$TotalRec);
	1 while ( $MessageStr =~ s/(\d)(\d{3})(\D)/$1,$2$3/ ) ;
	$MessageStr =~ s/\s([\d,]+)\)/\($1\)/ ;
	print "$MessageStr\n";
	$Colums[0]=keys(%TopDomains);
	$Colums[1]=keys(%TopDevices);
	$Colums[2]=keys(%TopApplication);
	$MessageStr=sprintf("\t\t-Num of Domains %d , num of Devices %d , num of Agents %d ",$Colums[0],$Colums[1],$Colums[2]);
	1 while ( $MessageStr =~ s/(\d)(\d{3})(\D)/$1,$2$3/ );
	print "$MessageStr\n";
}
close (CSVHADLE);
my $MessageStr=sprintf("Info  - %s - Finsh Parse $TotalRec Records.start Analyze",TimeStr());
1 while ( $MessageStr =~ s/(\d)(\d{3})(\D)/$1,$2$3/ ) ;
WrLog( $MessageStr);

my @TopReport= ( [\%TopDomains,"Visited URLs (by hits)"] ,
				 [\%TopDevices,"Devices (by hits/sessions)"] ,
				 [\%TopApplication,"Agents (by hits/sessions)"] );
				
my $Flag;				
foreach my $TopRec ( @TopReport )
{
	WrLog(sprintf("%s Info - Start Calculate top %s",TimeStr(),$TopRec->[1]));
	my $HashSize=keys(%{$TopRec->[0]});
	#WrLog("Debug - $TopRec->[0] $HashSize");
	my @LogLines;
	my $Counter=1;
	map { push(@LogLines,sprintf("%3d (%7d) %s",$Counter++,$TopRec->[0]->{$_},$_)) } GetTop($TopRec->[0],$G_CLIParams{Top}) ;
	WrLog("",sprintf("\tTop %d (of total %d) %s :",$G_CLIParams{Top},$HashSize,$TopRec->[1]),@LogLines);
	WrLog(sprintf("%s Info - Finish Calculation",TimeStr()));
	$Flag++;
}

my $ErrMessage= $G_ErrorCounter ? "Finish with ERRORS see Log File $G_CLIParams{LogFile}" :
		"Finish Successfully :-)";
EndProg($G_ErrorCounter,$ErrMessage);