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
#########################################################
#  Global variables
#########################################################

my $G_ErrorCounter=0;
my %G_CLIParams=(  LogFile  => "-" ,
					Gap		=> 50000 ,
					Csv		=> "HugeTest.csv" );
my @G_FileHandle=();

my @G_Suffix=( "co.il" , "org" , "com" ,"mail.il" ,"mail.com" ,"uk" ,"edu" ,"net.il" ,"gov","aero","mil","net","post","jobs","pro","int","info" );
my @G_Prefix=("http:/","https:/","ftp:/","sftp:/","file:/");
my @G_UrlList;

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
   my $Lines=shift;
   my $Err=0;
   my $Single;
   
   WrLog("Info\tWriting file $FileName.");
   open (INOUT,"> $FileName");
   if ( $? )
   {  
   	WrLog("Error\tFail to write to File $FileName");
   	return 1;
   }
   foreach $Single (@$Lines)
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

sub GenNum  ##$Start , $End
{
	my ($Start,$Stop)=@_;
	return int(rand($Stop-$Start + 1) )+ $Start ;
}

sub GenIP
{
	my @OctList;
	for ( my $i=4 ; $i ; $i-- )
	{
		push(@OctList,GenNum(0,255));
	}
	return join('.',@OctList);
}

sub GenWord
{
	my $Length=shift;
	my @Set=('A','a');
	my $Rang=ord('z')-ord('a');
	my ($Result,$UpCase);
	for ( my $i=0 ; $i < $Length ; $i++ )
	{
		$UpCase=int(rand($i+1)); #GenNum(0,$i+1);
		my $Test=int(rand($Rang));
		#WrLog(sprintf("Debug  ---  $Test %d , %d 
		$Result .= chr(int(rand($Rang)) + ord($UpCase ? $Set[1] : $Set[0]) ) ;
		#$Result .= chr(GenNum(ord($Set[$UpCase]->[0]),ord($Set[$UpCase]->[1])));
		#$Result .= 'a';
	}
	### WrLog("Deeeeeee Bug Word: $Result");
	return $Result;
}

sub getUrl
{
	#WrLog(sprintf("%s",rand($#G_UrlList+1)),@G_UrlList);
	my $dd=int(rand($#G_UrlList+1));
    return $G_UrlList[$dd] ;
	#return $G_UrlList[$@[0] % @G_UrlList] ;
}

sub GetFromList # \@List
{
	my $List=shift;
	my $Num=@$List;
	###  WrLog("Debug - Size of Array $Num");
	my $Index=int(rand($Num + 1) * rand(int($Num /2 ))) % $Num;
	return $List->[$Index];
}


sub GenUrl
{
	#my @Suffix=( "co.il" , "org" , "com" ,"mail.il" ,"mail.com" ,"uk" ,"edu" ,"net.il" ,"gov","aero","mil","net","post","jobs","pro","int","info" );
	#my @Prefix=("http:/","https:/","ftp:/","sftp:/","file:/");
	my @DnsWords=(1) x  (int(rand(2)) + 2) ; #   GenNum(1,3);
    for ( my $Wc=$#DnsWords ; $Wc  ; $Wc-- )
	{
		$DnsWords[$Wc - 1]=GenWord( int(rand(5)) + 3 - $Wc) ; #GenNum(6-$Wc,9));
	}
	$DnsWords[-1]=$G_Suffix[int(rand($#G_Suffix + 1))];
	### WrLog("Debug - Domain:",@DnsWords);
	#push(@DnsWords,$G_Suffix[GenNum(0,$#G_Suffix)]);
	my $Result=join('.',@DnsWords);
	@DnsWords=( 1 ) x int(rand(3)) ; #GenNum(0,3) ;
	for ( my $Wc=@DnsWords ; $Wc ; $Wc-- )
	{
		## push(@DnsWords,GenWord(GenNum(4,10)));
		$DnsWords[$Wc -1 ]=GenWord(int(rand(6))+4) ; # GenNum(4,10));
	}
	#return join('/',($G_Prefix[GenNum(0,$#G_Prefix)],$Result,@DnsWords)); 
	return join('/',($G_Prefix[int(rand($#G_Prefix + 1))],$Result,@DnsWords)); 
}

sub Factory
{
	my @HpiList;
	my @HttpErr=(200,201,400,404,500,501);
	my @DeviceList=("iphone","HTC","Anroide 4.0","Android 4.1","IOS");
	my @UserAgent=("IE 5.0","FireFox","Chrome","Curl","wget");
	my @Bearer=("2G","2.5G","3G","4G","LTE",-1);
	## for ( my $i
	my %ColList=( "URL"		=>  [\&GetFromList,\@G_UrlList] , ##\&getUrl , ### \&GenUrl , #### , 
			  "IP" 		=> \&GenIP , 
			  "Page Size" => [\&GenNum,250,75000] , 
			  "Number of Pics" => [\&GenNum,0,15] ,
			  "Number of Video" => [\&GenNum,0,5],
			  "Number of Ref"	=> [\&GenNum,1,25],
			  "Src Ref"	=> [\&GenNum,1,15],
			  "Pic Ref" => [\&GenNum,3,15],
			  "Video Ref"	=> [\&GenNum,1,5],
			  "time Load" 	=> [\&GenNum,600,30000] ,
			  "Max Pic Load"	=> [\&GenNum,10,300], 
			  "Headers Number" 	=> [\&GenNum,2,30], 
			  "Pic Comperation"	=> [\&GenNum,0,30],
			  "Iteration Count"	=> [\&GenNum,2,50]);
	my %TableColumns =( NODE_ID                =>  [\&GetFromList,\@HpiList] ,# IP Address of the HPI node that handles the transaction
                        MSISDN                 =>  [\&GenNum,1000000000,9999999999] , ,# Mobile Subscriber ISDN Number
                        TRANSACTION_URL        =>  [\&GetFromList,\@G_UrlList] ,# Host name or address and the relative path
                        RESPONSE_CODE          =>  [\&GetFromList,\@HttpErr],# HTTP Response code
                        START_TIME             =>  20131010 ,# Start time of the transaction
                        END_TIME               =>  20131011 ,# End time of the transaction
                        RESPONSE_ORIG_SIZE     =>  0 ,# Response original size.
                        DOWNLOAD_DATA_SIZE     =>  0 ,# Size of the HTTP response sent to client, without headers
                        SRC_IP                 => \&GenIP  ,# Source IP address of the transaction
                        ORIG_DST_IP            => \&GenIP ,# Original destination IP address of the transaction (as it came from client)
                        USED_DST_IP            => \&GenIP ,# Destination IP address of the transaction after URL DNS resolving (if no DNS -> ORIG_DST_IP)
                        SGSN_IP                => \&GenIP ,# IP address of the SGSN handling the transaction (from RADIUS start)
                        ACC_SESSION_ID         => 0 ,# Accounting session identifier (from RADIUS start)
                        IMEI                   => [\&GetFromList,\@DeviceList] ,# Client device International Mobile Equipment Identity.
                        USER_AGENT             => [\&GetFromList,\@UserAgent] ,# The user agent of the request
                        COMPRESSION_LEVEL      => -1 ,# Compression Level of the transaction 1-5
                        CONTENT_TYPE           => -1 ,# HTTP response MIME type
                        UPSTREAM_SIZE          => -1 ,# Size of the request data sent from the client side.
                        DOWNSTERAM_SIZE        => -1 ,# Size of the response data on the RAN side
                        OPTIMIZATION_FLAG      => -1 ,# Was optimization applied on response?
                        CA_FLAG                => -1 ,# Was content adaptation applied on response?
                        CC_FLAG                => -1 ,# Was content control applied on response?
                        CC_BLOCKED             => -1 ,# The action taken by the content control engine on the request
                        CC_REASON              => -1 ,# Reason for the CC block
                        CC_CATEGORY            => -1 ,# The category for the CC block
                        INITIAL_BEARER         => [\&GetFromList,\@Bearer] ,# Original network bearer (from RADIUS start)
                        NETWORK_BEARER         => [\&GetFromList,\@Bearer] ,# Discovered network bearer
                        APN_IP                 => \&GenIP ,# IP address of the APN used for transaction (from RADIUS start)
                        POC_HIT                => [\&GenNum,0,1] ,# Was the request served from post optimization cache
                        ORIGINAL_REQUEST_HOST  => -1 ,# Video top level domain (in case part of a pre-configured list of websites
                        ORG_CONTENT_LENGTH     => -1 ,# Video content length before compression
                        CONTENT_LENGTH         => -1 ,# Video content length after compression
                        MD5_STRING             => -1 ,# Video identifier in case video was requested from the beginning
                        SEEK_MD5_STRING        => -1 ,# Video identifier in case video was requested from the middle
                        BITRATE                => -1 ,# Average video bitrate
                        IS_BUFFER_LIMITING     => 36 ,# Is buffer tuning activated
                        IS_VIDEO_FROM_CACHE    => 37 ,# Is the video served from the cache
                        IS_VIDEO_SEEK_REQUEST  => 38 ,# Is the video requested from the middle
                        AUDIO_CODEC            => 39 ,# What is the audio encoding
                        VIDEO_CODEC            => 40 ,# What is the video encoding
                        MEDIA_CONTAINER        => 41 # What is the video file format
					); 
	my @Collumns=keys(%ColList);
	for ( my $i=5; $i ; $i--) { push(@HpiList,GenIP()); }
	my $Type = exists $G_CLIParams{Type} ? $G_CLIParams{Type} : "csv" ;
	my %Result;
	if ( $Type eq "csv" )
	{
		$Result{Func}= \%ColList ;
		$Result{ColumnsOrder}=\@Collumns;
		$Result{Token}=',';
		$Result{Title}=join(',',@Collumns);
	} else
	{
		$Result{Func}= \%TableColumns ;
		$Result{ColumnsOrder}=["NODE_ID","MSISDN","TRANSACTION_URL","RESPONSE_CODE","START_TIME",
							"END_TIME","RESPONSE_ORIG_SIZE","DOWNLOAD_DATA_SIZE","SRC_IP","ORIG_DST_IP",
							"USED_DST_IP","SGSN_IP","ACC_SESSION_ID","IMEI","USER_AGENT","COMPRESSION_LEVEL",
							"CONTENT_TYPE","UPSTREAM_SIZE","DOWNSTERAM_SIZE","OPTIMIZATION_FLAG",
							"CA_FLAG","CC_FLAG","CC_BLOCKED","CC_REASON","CC_CATEGORY","INITIAL_BEARER",
							"NETWORK_BEARER","APN_IP","POC_HIT","ORIGINAL_REQUEST_HOST","ORG_CONTENT_LENGTH",
							"CONTENT_LENGTH","MD5_STRING","SEEK_MD5_STRING","BITRATE","IS_BUFFER_LIMITING",
							"IS_VIDEO_FROM_CACHE","IS_VIDEO_SEEK_REQUEST","AUDIO_CODEC","VIDEO_CODEC","MEDIA_CONTAINER"];
		$Result{Token}="\t";
	}
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


my %ObjRec=Factory();



my @Cvl= exists $ObjRec{Title} ? ($ObjRec{Title}) : () ; #  (join(',',@Collumns));
my $MaxIter=$G_CLIParams{Rec} > 20000000 ? 1000000 : int($G_CLIParams{Rec} / 20) ;
WrLog("Debug -- $ObjRec{Title} ...",@Cvl);
@G_UrlList= (1) x $MaxIter;
WrLog("Info - Genereting Url list $MaxIter");
#exit 0;


for ( my $i=$MaxIter; $i ; $i-- )
{
	#push(@UrlList,GenUrl());
	##WrLog("Debug  $i ....");
	$G_UrlList[$i-1]=GenUrl();    ##GenWord(int(rand(8)));        #(GenNum(3,8));   ###GenUrl();
	$i % $G_CLIParams{Gap} or WrLog(sprintf("Info  - %6.2f% Records to end of generation ....",$i * 100.0 / $MaxIter) );
}

my @DArr=localtime() ;
WrLog(sprintf("%02d:%02d:%02d - Finish Build Urls List",$DArr[2],$DArr[1],$DArr[0]));
# exit 0;
#$G_ErrorCounter +=  WriteFile($G_CLIParams{Csv},\@Cvl);
#open CVLFILE , ">> $G_CLIParams{Csv}"; 
my %Tester;

map { $Tester{$_}=1 ;} @G_UrlList;

my $Num=keys(%Tester);

WrLog("Debug - Number of Uniq Urls is $Num");
%Tester={};



$MaxIter=$? ? 0: $G_CLIParams{Rec} ;
for ( my $i=$MaxIter; $i ; $i-- )
{
	my $TmpUrl=GetFromList(\@G_UrlList);
	$Tester{$TmpUrl}++;
	$TmpUrl=keys(%Tester);
	$i % $G_CLIParams{Gap} or WrLog(sprintf("Plesae wait .... stil processing %6.2f% ($TmpUrl diff Urls)....",$i * 100.0 / $MaxIter) );
}			  

##WrLog(@Cvl);

##$G_ErrorCounter += WriteFile($G_CLIParams{Csv},\@Cvl);			  
$G_ErrorCounter += $?;
@DArr=localtime() ;
my $TimeStr=sprintf("%02d:%02d:%02d - Finish Build Urls List",$DArr[2],$DArr[1],$DArr[0]);
my $ErrMessage= $G_ErrorCounter ? "Finish with ERRORS see Log File $G_CLIParams{LogFile}" :
		"$TimeStr - Finish Successfully :-)";
EndProg($G_ErrorCounter,$ErrMessage);