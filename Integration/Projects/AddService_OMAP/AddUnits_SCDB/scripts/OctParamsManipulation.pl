#!/usr/cti/apps/CSPbase/Perl/bin/perl

##################################################################
#  20/7/2011 
#  This Script should be update ( fix ) to manipulate xmls files
# with use XML::LibXML;
# and to manipulate ini files using %IniRec functions
#
#   Todo:
#

use strict;
use XML::LibXML ;

#########################################################
#  Global variables
#########################################################

my $G_ErrorCounter=0;
my %G_CLIParams=(  LogFile  => "-" );
my @G_FileHandle=();
my $G_Null="\$NULL";
my %G_OSCmds;

sub usage
{
    print "$0 -Conf Filename [-Unit UnitType][-LogFile FileName]\n";
    print "$0 -help\n";
    print "* Conf    - configuration file. which contains all parameters mapping.\n";
    print "* LogFile - logger file name.\n";
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
    	my @WeekDays=("Sunday","Monday","Tuesday","Wednesday","Thurthday","Friday","Saturday");
    	PrnTitle("Start $0",sprintf("at %-14s %02d/%02d/%4d $DArr[2]:%02d",$WeekDays[$DArr[6]],$DArr[3],
    			$DArr[4]+1,$DArr[5]+1900,$DArr[1]));
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
   my @DArr=localtime();
   my $BackFile=sprintf("%4d_%02d_%02d_%02d%02d%02d",$DArr[5]+1900,$DArr[4]+1,$DArr[3],$DArr[2],$DArr[1],$DArr[0]);
   my $Suffix="Backup_";
   my $JustFile ;
   
   unless ( -e $OrigFile )
   {
   	WrLog("Error\tFail to backup file $OrigFile. file Not exists.");
   	$G_ErrorCounter++;
   	return ;
   }
   my $Counter=1;
   $BackFile = "$OrigFile.$Suffix$BackFile";
   ### Make sure there is no duplicate backup Files ####
   while ( -e $BackFile )
   {
   	$BackFile .= "$Counter" ;
   	$Counter++;
   }
   $OrigFile =~ m/(^|\/)([^\/]+)$/ ;
   $JustFile = $2;
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
# Return:	0 - for O.K , != for errors
#
# Description: Write the @Content Lines into $FileName Don't Overwrite.
#
###############################################################################
{
   my $FileName=shift;
   my @Lines=@_;
   my $Backup=BackupFile($FileName);
   
   unless ( $Backup )
   {
       	WrLog("Error\tFail to Backup $FileName .");
 	return 1;  	    
   }
   WrLog("Info\tRewriting file $FileName.");
   if ( WriteFile($FileName,@Lines) )
   {
   	WrLog("Error\tFail to write file $FileName");
   	if ( -e $Backup )
   	{
   	    WrLog("Info\tResotring the Original file $FileName");
   	    $G_ErrorCounter += RunCmds("mv -f $Backup $FileName");
   	    return 1;
   	}
   } else
   {
		$G_ErrorCounter += RunCmds("chown --reference=$Backup $FileName" ,
								   "chmod --reference=$Backup $FileName" );
		WrLog("Note:\tTo restore the file use $Backup\n");
   }
   return 0;
}

sub ParseSections 
###############################################################################
#
# Input:	\%IniRec
#
# Return:	0 - O.K 1 Error
#
# Description:  Parse the content and retun Update IniRec
#		IniRec = {SecTion Name} [startLine,EndLine]
#		Resrved names (FileName,Content)
#
###############################################################################
{
    my $Pointer=shift;
    ### WrLog("--- Debug in ParseSections ....","","");
    unless ( defined $$Pointer{Content} )
    {
    	WrLog("Error - IniRec is missing. ParseSections get empty content. file name \"$$Pointer{FileName}\"");
    	return 1;
    }
    ## WrLog("Debug:\tParsing ini file \"$$Pointer{FileName}\"");
    my $Content=$$Pointer{Content};
    my ($SecName,$LastName);
    my $Start=0;
    my $Tmp = $#$Content ;
    ## WrLog("Debug - Number of Lines: $Tmp");
    for ( my $Indx=0 ; $Indx <= $#$Content ; $Indx++ )
    {
    	$$Content[$Indx] =~ /^\s*\[(.+)\]/ or next ;
    	$SecName=$1;
    	###defined $LastName or next ;
    	$$Pointer{$LastName}=[$Start,$Indx-1];
    	$Start=$Indx+1;
    	$LastName=$SecName;
    	## WrLog("Debug: Add Section $SecName ...");
    }
    defined $LastName and $$Pointer{$LastName}=[$Start,$#$Content];
    return 0;
}

sub ReadSections 
###############################################################################
#
# Input:	\%IniRec,@SectionName
# Return:  %Hash - contain all the key->val
#
# Description: transform from "param=val" to hash.
#              if there are varios param instancess the hash will retrun List ref
#
###############################################################################
{
    my $Pointer=shift;
    my @Sections=@_;
    ### WrLog("Debug:\tIni File $$Pointer{FileName}:",@Sections);
    my %Result;
    foreach my $Sec (@Sections)
    {
    	## WrLog("Debug:\tParsing Section $Sec");
    	unless ( defined $$Pointer{$Sec} )
    	{
    	    WrLog("Error: Fail to find sector \"$Sec\" at file $$Pointer{FileName}");
    	    $G_ErrorCounter++;
    	    next;
    	}
    	my $TmpPoint=$$Pointer{$Sec};
    	## WrLog("Debug - Section $Sec Range is :",@$TmpPoint);
    	my $ContPoint=$$Pointer{Content};
    	my @Lines=@$ContPoint[$$TmpPoint[0]..$$TmpPoint[1]];
    	## WrLog("Debug: Section $Sec Content:",@Lines);
    	foreach my $Line ( grep (/^\s*[^#]/,@Lines) )
    	{
    	    $Line =~ /(.+?)=(.+)/ or next ;
    	    ### This is Relevant if there is Multi values at Section ....
    	    my $Base=$1;
    	    my $KeyName=$Base;
			if ( exists $Result{$KeyName} )
			{
				if ( ref $Result{$KeyName} )
				{
					push(@{$Result{$KeyName}},$2);
				} else
				{
					$Result{$KeyName}=[$Result{$KeyName},$2];
				}
			} else
			{
				$Result{$KeyName}=$2;
			}
    	}
    }
    return %Result;
}



sub SetSection
###############################################################################
#
# Input:	\%IniRec,$SectionName,%HashParam
#
# Return:	0 - O.K, 1 - Error
#
# Description:  Update parameters in section. if the parameter no exists add it.
#		if the section not exist add new section
#
###############################################################################
{
    my $IniRec=shift;
    my $SecName=shift;
    my %HashParams=@_;
    my @NewContent;
    my $Point=$$IniRec{Content};
    my ($StartIndx,$EndIndx);
    ### Check if the section already exists
    unless ( exists $IniRec->{$SecName} )
    {
    	WrLog("Info:\tNew section \"$SecName\" add to Ini file $$IniRec{FileName}");
    	push(@$Point,"[$SecName]");
    	$EndIndx=$#$Point;
    	$StartIndx=$EndIndx + 1;
    } else
    {
    	($StartIndx,$EndIndx)=@{$$IniRec{$SecName}};
    }
    @NewContent=@$Point[0..$EndIndx];
    ### update exist parameters at the section
    for ( my $LineNo=$StartIndx;  $LineNo <= $EndIndx ; $LineNo++ )
    {
    	$NewContent[$LineNo] =~ /^\s*([^#].*)=/ or next;
    	my $ParaName=$1;
    	exists $HashParams{$ParaName} or next ;
		#####  WrLog("Debug ---- Update Value of $ParaName at Ini Record to $HashParams{$ParaName} .........");
		my $ParamContent="$ParaName=$HashParams{$ParaName}";
		if ( ref $HashParams{$ParaName} )
		{
			WrLog("Warning - $ParaName : " . ( exists $HashParams{$ParaName}->{Error} ? $HashParams{$ParaName}->{Error} : 
						" There is no value for this parameter skip update"));
			$HashParams{$ParaName}->{Orig}=$NewContent[$LineNo];
			$ParamContent=$HashParams{$ParaName};
		}  
		$NewContent[$LineNo]=$ParamContent;
    	delete $HashParams{$ParaName};
    }
    while ( my ($ParaName,$ParamVal) = each(%HashParams) )
    {
		ref $ParamVal or push (@NewContent,"$ParaName=$ParamVal") ,next;
		WrLog("Warning - $ParaName : " . ( exists $HashParams{$ParaName}->{Error} ? $HashParams{$ParaName}->{Error} : 
				" There is no value for this parameter skip update") );
    }
    my ($Indx1,$Indx2)=($EndIndx + 1, $#$Point);
    push(@NewContent,@$Point[$Indx1..$Indx2]);
    $$IniRec{Content}=\@NewContent;
    return ParseSections($IniRec);
}

sub LoadIniFile
###############################################################################
#
# Input:     $Filename
#
# Return:    %IniRec
#
# Description:  ReadInifile and return iniRec:
#               IniRec = {FileName} => The Ini File Name
#			 {Content}  => \@Ini FileContent Lines
#			 {<SecName>}=> (Start,End)
#
###############################################################################
{
    my $FileName=shift;
    my $Err=$G_ErrorCounter;
    my @Content=ReadFile($FileName);
    $G_ErrorCounter > $Err and WrLog("Error - Fail to read ini File."),return;
    $#Content < 0 and WrLog("Warning - Content of $FileName is Empty !");
    my %Result = ( FileName	=> $FileName ,
    		   Content	=> \@Content );
    my $Err=ParseSections(\%Result);
    $Err and WrLog("Error: Parsing $FileName");
    return  $Err ? 0 : %Result ;
}

sub UpDateIniFile
###############################################################################
#
# Input:	\%IniRec
#
# Return:	0 - O.K , 1 Error
#
# Description: write ini File acording to content.
#
###############################################################################
{
    my $Rec=shift;
    my $Content=$$Rec{Content};
    my $Err = -e $$Rec{FileName} ? UpdateFile($$Rec{FileName},@$Content) : WriteFile($$Rec{FileName},@$Content);
    return $Err;
}

sub CreateIniFile
###############################################################################
#
# Input:	$FileName
#
# Return:	%IniRec
#
# Description:
#
###############################################################################
{
    my $FileName=shift;
    my @Content=();
    my %Result = ( FileName	=> $FileName ,
    		   Content	=> \@Content );
    return -e $FileName ? LoadIniFile($FileName) : %Result ;
}

sub ParamsMapping 
###############################################################################
#
# Input:	\%Config.
#		Reference to Configuration Hash
#
# Return:	%Parameters
#		parametrs Hash file Hash{Parametr Name}->Value
#
# Description:	This function get the configuration and Map from octopus
#		parameters to Real parameters.
#
###############################################################################
{
   my $ConfigPointer=shift;
   my %Result=();
   my $Err=0;
   my %OctParams=ReadSections($ConfigPointer,"Octopus.Parameters.Mapping");
   my %OctVals=ReadSections($ConfigPointer,"Values");
   my %Macros=ReadSections($ConfigPointer,"Macros");
   
   my (@RealParamsList,%Ruls,@ParamValues);
   
   if ( defined $G_CLIParams{D} )
   {
   	my @LogMessage=("Debug - Input Parameters values:");
   	while ( my ($Param,$PVal) = each(%OctVals) )
   	{
   		push(@LogMessage,sprintf("\t%-19s : %40s",$Param,$PVal));
   	}
   	WrLog(@LogMessage,'-' x 60);
   }
   
   while ( my ($OctParamName,$ParamList) = each (%OctParams) )
   {
		exists $G_CLIParams{D} and WrLog("Debug - Start Mapping $OctParamName ...");
		ref $ParamList and WrLog("Error - Multiple Mapping definition for \"$OctParamName\""),$G_ErrorCounter++,next;
		#### ToDO - If there is missing Value write just Warning - maybe the parameters are not relevant ...
		unless ( exists $OctVals{$OctParamName} )
		{
			WrLog("Warninig - Missing Octopus Parameter value for $OctParamName.");
			foreach my $Iter ( split(',',$ParamList) )
			{
				$Result{$Iter}= { Error		=> "Missing Value of Depenedence parameter  $OctParamName" ,
								  Ref		=> $OctParamName };
			}
			# $G_ErrorCounter++;
			next;
		}
		## check if there is missing Rule for $OctParamName
		$Err=$G_ErrorCounter ;
		### Go Over the Maping Ruls of this parameter ...
		#%Ruls=ReadSections($ConfigPointer,"Octopus.Parameters.Def.$OctParamName");
		unless ( exists $ConfigPointer->{"Octopus.Parameters.Def.$OctParamName"} )
		{
			WrLog("Error - Missing Mapping rules for octopus Parameter \"$OctParamName\"");
			$G_ErrorCounter++;
			next;
		}
		###  This is a default mapping Rule for the case that the Mapping Value is defined at null:
		#    Example: [Octopus.Parameters.Mapping]
		#             Var1=Var2,Var3
		#             [Values]
		#             Var1=$NULL
		@RealParamsList=split(',',$ParamList);
		if ( $OctVals{$OctParamName} eq $G_Null )
		{
			foreach my $Iter ( @RealParamsList )
			{
				$Result{$Iter}=$G_Null ;
			}
		} else
		{	### Calculate Values
			my $Limit=$ConfigPointer->{"Octopus.Parameters.Def.$OctParamName"};
			my $TmpStr;
			#### Go Over all the Rules till the first match
			for ( my $Indx=$Limit->[0] ; $Indx <= $Limit->[1] ; $Indx++ )
			{
				exists $G_CLIParams{D} and WrLog("Debug - Parsing Mapping Rule at Line $Indx");
				$ConfigPointer->{Content}->[$Indx] =~ /^\s*(#|$)/ and next ;
				unless ( $ConfigPointer->{Content}->[$Indx] =~ /^(.+=\S)(.+)/ )
				{
					WrLog(sprintf("Error - Line %d: \"%s\"",$Indx + 1,$ConfigPointer->{Content}->[$Indx]));
					$G_ErrorCounter++;
					next;
				}
				my ($Prefix,$Sufix)=($1,$2);
				####    Replace all Macros + all values  #####
					### Pahss 1 Find all relevant Macros and parameters ( Put Replace Token if no change should be done )
				my %TmpTokens=();
				my $Count=1;
				my @SerachRec=( [q/%\$(.+?)%/,\%Macros,q/%\\\$$IndKey%/] , [q/[^\\\\]\{([^\}\{]+)\}/,\%OctVals,q/\{$IndKey\}/] ) ;
				foreach my $SRec ( @SerachRec )
				{
					exists $G_CLIParams{D} and WrLog("Debug - Using RegExp \"$SRec->[0]\"");
					while ( $Sufix =~ /$SRec->[0]/ )
					{
						my $IndKey=$1;
						unless( exists $SRec->[1]->{$IndKey} )
						{
							$TmpStr=sprintf("###Replace%d###",$Count);
							$TmpTokens{$TmpStr}=eval("\"$SRec->[2]\"");;
						} else 
						{
							exists $G_CLIParams{D} and WrLog("Debug - Replace Macro/Value $IndKey with $SRec->[1]->{$IndKey}");
							$TmpStr= $SRec->[1]->{$IndKey};
						}
						my $Tmp=eval("\"$SRec->[2]\"");
						exists $G_CLIParams{D} and WrLog("Debug - Eval Result: $Tmp");
						$Sufix =~ s/$Tmp/$TmpStr/ ;
						$Count++;
						exists $G_CLIParams{D} and WrLog("Debug - After Replace Macro/Value Line ($Tmp) : $Sufix");
					}
				}
				
				###  Return back all Relace tokens
				while ( $Sufix =~ s/(###Replace\d+###)/$TmpTokens{$1}/ ) {}
				exists $G_CLIParams{D} and WrLog("Debug - After Value/Macro Replace Line: $Prefix$Sufix");
				@ParamValues=ValCalculate($OctVals{$OctParamName},"$Prefix$Sufix",\%OctVals);
				@ParamValues or next;
				unless ( $#RealParamsList == $#ParamValues )
				{
					WrLog(sprintf("Error - \"$OctParamName\" requiers %d Parameters but the Map rull return %d Values:",
									$#RealParamsList+1,$#ParamValues +1 ),@ParamValues);
					$G_ErrorCounter++;
					@ParamValues=();
				}
				last ;
			}
			if ( @ParamValues )
			{	## a rull have been match assign the values to parameters
				for ( my $Iter=0; $Iter <= $#ParamValues; $Iter++ )
				{
					exists $OctVals{$RealParamsList[$Iter]} and WrLog("Warning - Value of $RealParamsList[$Iter] is overwrite due to mapping Rule");
					$Result{$RealParamsList[$Iter]}=$ParamValues[$Iter];
					WrLog(sprintf("Info - Update %-30s with value $ParamValues[$Iter]",$RealParamsList[$Iter]));
				}
			} else
			{
				WrLog("Error - Fail to find Matching rul for parameter $OctParamName");
				$G_ErrorCounter++;
			}
		}
   }
   return %Result;
}

sub RegExpCheck
{
	my $Pattern=shift;
	my $PVal=shift;
	my @Params=@_;
	my @Result;
	$PVal =~ /$Pattern/ or return;
	foreach my $Iter (@Params)
	{
		push(@Result,$Iter eq $G_Null ? $G_Null : eval(qq("$Iter"))) ;
		exists $G_CLIParams{D} and WrLog("Debug -  Evalute $Iter - \"$Result[-1]\"");
	}
	return @Result
}

sub IsNumber
{
	return $_[0] =~ /^-?\d+(\.\d+)?$/ ? 1 : 0;
}

sub NumberMan
{
	my $PVal=shift;
	my @Params=@_;
	my $OpCh = q(\-\*/%^+~) ;
	my @Result;
	exists $G_CLIParams{D} and WrLog("Debug -  NumberMan Input:",@Params);
	foreach my $Iter (@Params)
	{
		my $EvalStr=$Iter;
		if ( $Iter =~ /^[\s\d$OpCh\(\)\.]+$/ )
		{
			IsNumber($PVal) and $Iter =~ /^\s*[$OpCh]/ and $EvalStr = "$PVal $Iter";
			$Iter = eval($EvalStr);
		}
		push(@Result,$Iter) ;
		exists $G_CLIParams{D} and WrLog("Debug -  Evalute $EvalStr  - \"$Iter\"");
	}
	return @Result
}

sub ChkEq #$RulKey,$PVal,@Listof ManParams
{
	my $RulKey=shift;
	return $_[0] eq $RulKey ? NumberMan(@_) : () ;
}

sub ChkNotEq #$RulKey,$PVal,@Listof ManParams
{
	my $RulKey=shift;
	return $_[0] ne $RulKey ? NumberMan(@_) : () ;
}

sub ChkBiger #$RulKey,$PVal,@Listof ManParams
{
	my $RulKey=shift;
	unless ( IsNumber($RulKey) )
	{
		WrLog("Error - Illegal Mapping Rule the left side should be acnumber instead of $RulKey");
		$G_ErrorCounter++;
    	return ;
	}
	exists $G_CLIParams{D} and WrLog("Debug - Check if $_[0] is gt (Grate than) $RulKey");
	return $_[0] > $RulKey ? NumberMan(@_) : () ;
}

sub ChkLower #$RulKey,$PVal,@Listof ManParams
{
	my $RulKey=shift;
	unless ( IsNumber($RulKey) )
	{
		WrLog("Error - Illegal Mapping Rule the left side should be acnumber instead of $RulKey");
		$G_ErrorCounter++;
    	return ;
	}
	return $_[0] < $RulKey ? NumberMan(@_) : () ;
}

sub ValCalculate 
###############################################################################
#
# Input: $Value,$Rull Line, \%ValRecList	------------$Value,\%MapRuls
#		$Value - is the actual Octopus value (which should be map to real values.
#		%MapRuls - Hash file that contain the mapping ruls.
#
# Return:	@List of values
#
# Description:
#
###############################################################################
{
    my $ActValue=shift;
	my $RulLine=shift;
	my $ValueRef=shift;
    my %ListDet=( "=" => \&ChkEq ,
				  "~" => \&RegExpCheck ,
				  ">" => \&ChkLower ,
				  "<" => \&ChkBiger ,
				  "!" => \&ChkNotEq );
    my $OpList=join('',keys(%ListDet));
    my ($RuleKey,$ValDef,$OpCh);
	
	$RulLine =~ /(.+?)=([$OpList])(.+)/ or WrLog("Error - Unsupported Rul Syntax: \"$RulLine\""), return;
	$RuleKey =$1 ;
	$OpCh=$2;
    $ValDef=$3;
	my $Err=$G_ErrorCounter;
	$ValDef=~ s/(([^\\]),)/$2$1/g ;
	### ToDO - Replace all \, to , ....
	my @Result=$ListDet{$OpCh}->($RuleKey,$ActValue,split(/[^\\],/,$ValDef)) ;
	@Result or WrLog("Debug - Return Empty Recs !!!!!!");
	foreach ( @Result )
	{
		s/\\,/,/g ;
	}
	$Err > $G_ErrorCounter and WrLog("Error - During Maping Rule parsing: \"$RulLine\"");
	return @Result;
}

sub GetParamRec
###############################################################################
#
# Input:	$ParamDefStr,\%Macros
#
# Return:	%Record
#
# Description: Parse the Parameter definition and return Record
#		%Record => {FileType} = txt or ini or xml or cmd
#			   {UnitList} = List of of units ( "," comma seperate
#					That this parameter is relevant.
#		  Depened on File Type:
#			   {FileName} 
#			   {Xpath}
#			   {SecName}
#			   {ParamName}
#			   {Op}
#			   {CmdName}
#			   {CLIParams}
###############################################################################
{
    my $Rec=shift;
    my $Macros=shift;
    my ($UnitList,$FileType,$FileName,$Xpath,%Result);
    my %ParseTmpl= (cmd => "(\\S+)\\s*(\\S.*)?\$;;;CmdName;;;CLIParams" ,
    	            xml => "(.+?)\\\/\\\/(.+)\$;;;FileName;;;Xpath" ,
    	            ini => "(.+)\\\/\\[([^\\]]+)\](.+)\$;;;FileName;;;SecName;;;ParamName" ,
    	            txt =>  q{(.+)\/\/(\[[^\]]*\])?(.*)$;;;FileName;;;Op;;;ParamName} , 
    	            farm => "(.+?):(.+)\$;;;Farm;;;Port"      )  ;
    		    
    ####   extract Macros before manipulation  ###
    
    while ( $Rec =~ /\%\$(.+?)\%/ )
    {
    	my $MacroName=$1;
    	defined $G_CLIParams{D} and WrLog("Debug - Extracting Macro $MacroName");
		my $MacVal= exists $Macros->{$MacroName} ? $Macros->{$MacroName} : undef ;
    	unless ( $MacVal )
    	{
    	     WrLog("Warning - Unknown Macro \"$MacroName\" !. Empty value will be assign.");
			 $Result{Error}="Fail to Extract Macro \"$MacroName\"";
    	     ## $G_ErrorCounter++;
    	     ## return ;
    	}
    	$Rec =~ s/\%\$$MacroName\%/$MacVal/ ;
    }
    
    unless ( $Rec=~ m/^(.+?),([^,]+?):\/\/(.+)$/ )
    {
    	WrLog("Error - Mismatch Parameter Definition \"$Rec\"");
    	$G_ErrorCounter++;
    	return ;
    }
    $Result{UnitList} = $1 ;
    $Result{FileType} = $2 ;
    my $Def=$3;
    unless ( defined $ParseTmpl{$Result{FileType}} )
    {
    	WrLog("Error - Wrong File Type \"$Result{FileType}\" at parameter defintion \"$Rec\"");
    	$G_ErrorCounter++;
    	return ;
    }
    my @Fields=split(";;;",$ParseTmpl{$Result{FileType}});
    my $RegExp=shift(@Fields);
    unless ( $Def =~ m/$RegExp/ )
    {
    	WrLog("Error - wrong parameter definition $Rec",
    	      "\tRegExp=$RegExp");
    	$G_ErrorCounter++;
    	return ;
    }
    for (my $Fnum=0 ; $Fnum <= $#Fields ; $Fnum++ )
    {
        eval(sprintf("\$Result{%s}=\$%d",$Fields[$Fnum],$Fnum+1));
        exists $G_CLIParams{D} and WrLog("Debug - Add to Record $Fields[$Fnum] --> $Result{$Fields[$Fnum]}" );
    }
    return %Result
}

sub ParamsSettings 
###############################################################################
#
# Input:	\%Configuration,$Unit
#
# Return:
#
# Description: Update all parameters at the files.
#	       %Configuration -> the configuration ( the file maping definition)
#	       $Unit - The unit that has to be update ( all other units will be ignore)
#
###############################################################################
{
    ## my $ParamsList=shift;
    my $ConfPointer=shift;
    my $Unit=shift;
    
    my $ExecFunc;
    my %ItemsList=( xml => [\&xmlSetting] ,
    	       	    ini => [\&IniSettings] ,
    	       	    txt => [\&txtSettings] ,
    	       	    cmd => [\&cmdSettings] ,
    	       	    farm => [\&FarmSettings]);
    my %ExecList=();
    my %Macros = exists $ConfPointer->{Macros} ? ReadSections($ConfPointer,"Macros") : () ;
    my $Err=$G_ErrorCounter;
    my %RealParam=ReadSections($ConfPointer,"RealName.Parameters.Def");
    my %ParamsValue=ReadSections($ConfPointer,"Values");
    # defined $$ConfPointer{Macros} and %Macros=ReadSections($ConfPointer,"Macros");
    $Err == $G_ErrorCounter or WrLog("Error - missing configuration section \"RealName.Parameters.Def\"",
    				     "        or \"Values\" at $$ConfPointer{FileName}"),return 1;
    ## Go Over all Parameters Definitions #####
    while ( my ($Parameter,$ParamDef) = each(%RealParam) )
    {
		exists $G_CLIParams{D} and WrLog("Debug - \"$Parameter\" Record Definition:");
		my @ParamRecList= ref $ParamDef ? @$ParamDef : ($ParamDef) ;
		## my %ParamRec;
		foreach my $ParamIns (@ParamRecList)
		{
		
			my %ParamRec=GetParamRec($ParamIns,\%Macros);
			unless ( exists $ParamRec{UnitList} )
			{
				WrLog("Error - Skip configuration of \"$Parameter\". wrong path definition:",
							"        $ParamIns");
				$G_ErrorCounter++;
				next;
			}
			unless ( $ParamRec{UnitList} =~ m/(^|,)$Unit(,|$)/ )
			{ 
				exists $G_CLIParams{D} and WrLog("Debug - Skip Parameter \"$Parameter\"setting. Not relevant Unit $Unit $ParamRec{UnitList}");
				next ; 
			}
			unless ( exists $ItemsList{$ParamRec{FileType}} )
			{
				WrLog("Error - unsupported file Type \"$ParamRec{FileType}\". at definition of parameter \"$Parameter\"");
				$G_ErrorCounter++;
				next;
			} 
			### check if there is  a value 
			###        defined $ParamsValue{$Parameter} or $ParamsValue{$Parameter}="" , WrLog("Warning - No Value for $Parameter");
			unless ( exists $ParamsValue{$Parameter} and ! ( ref ($ParamsValue{$Parameter} ) ) )
			{
				WrLog("Error - " . (exists $ParamsValue{$Parameter} ? $ParamsValue{$Parameter}->{Error} : "Missing Value for Parameter $Parameter") );
				$G_ErrorCounter++;
				next;
			}
			if ( $ParamsValue{$Parameter} eq $G_Null )
			{
				WrLog("Info  - $Parameter has Null value - skiping leave default value.");
				next;
			}
			exists $ParamRec{Error} and WrLog("Error - at Parameter $Parameter : $ParamRec{Error}"),$G_ErrorCounter++,next;
			$ParamRec{Name}=$Parameter;
			$ParamRec{Value}= $ParamsValue{$Parameter} ;
			exists $G_CLIParams{D} and WrLog("Debug - Insert to $Parameter -> $ParamsValue{$Parameter}");
			
			
			### Update  Command Parameters 
			if ( exists $ParamRec{CLIParams} )
			{
				my ($Count,$RepStr,%RepIndx);
				for ( ($Count,$RepStr)=(1,"###Replace1###") ; $ParamRec{CLIParams} =~ s/((^|[^\\])\{([^\}\{]+)\})/$RepStr/ ;  $Count++ , $RepStr="###Replace$Count###" )
				{
					my $AllStr=$1;
					my $Pref=$2;
					my $IndKey=$3;
					my $ContStr= exists $ParamsValue{$IndKey} ? "$Pref$ParamsValue{$IndKey}" : $AllStr ;
					$RepIndx{$RepStr}=$ContStr;
					exists $G_CLIParams{D} and WrLog("Debug - Save at $RepStr -> \"$ContStr\"");
				}
				###  Return back all Relace tokens
				while ( $ParamRec{CLIParams} =~ s/(###Replace\d+###)/$RepIndx{$1}/ ) {}
			}
			exists $G_CLIParams{D} and WrLog("Debug - calling function manipulation \"$ParamRec{FileType}\"");
			my $Poiter=$ItemsList{$ParamRec{FileType}};
			push(@$Poiter,\%ParamRec);
    	}	
    }
    exists $G_CLIParams{D} and WrLog("Debug - ****  Start Update Files with real values  ****");
    while ( my ($FType,$Array) = each(%ItemsList) )
    {
    	$ExecFunc=shift(@$Array);
    	$#$Array < 0 and next;
    	exists $G_CLIParams{D} and WrLog("Debug - Start handeling $FType ...");
    	$G_ErrorCounter += &$ExecFunc(@$Array);
    	#### Clean System Error ... ###
    	while ( $? ) { $ExecFunc=`echo`; }
    	###WrLog("Debug -              Finish To Handeling $FType  Going to Next Type ..............................");
    }
}

sub xmlSetAttr
###############################################################################
#
# Input:	$root,Xpath,%AttrValues
#
# Return:
#
# Description: Set Node and Attributes
#
###############################################################################
{
    my $XmlObj=shift;
    my $Xpath=shift;
    my $XAttr=shift;
    defined $G_CLIParams{D} and WrLog("Debug - Update $Xpath Attributes .... ");
    $Xpath =~ s/\/$// ;
    my @Nodes=$XmlObj->findnodes($Xpath);
    $#Nodes < 0 and WrLog("Error - Xpath not found \"$Xpath\" (at SetAttr)",$XmlObj->toString),return 1;
    foreach my $Node (@Nodes)
    {
    	while ( my ($AttrName,$AttrVal) = each (%$XAttr) )
    	{
     		$Node->setAttribute($AttrName,$AttrVal);
     		defined $G_CLIParams{D} and WrLog(sprintf("Debug - Update %s with $AttrName = $AttrVal",$Node->nodePath()));
     	}
    }
    return 0;
}

sub xmlSetVal
###############################################################################
#
# Input:	$root,Xpath,Val
#
# Return:
#
# Description:   set Element Val
#
###############################################################################
{
     my $XmlObj=shift;
     my $Xpath=shift;
     my $XValue=shift;
     my ($Indx,$NewNode);
     ### get Path of new Node  ###
     my @Nodes=$XmlObj->findnodes($Xpath);
     $#Nodes < 0 and WrLog("Error - Xpath not found $Xpath"),return 1;
     $NewNode=XML::LibXML::Text->new($XValue);
     foreach my $Node (@Nodes)
     {
		my $NodeName=$Node->nodeName;
		my $NewNode=XML::LibXML::Element->new($NodeName);
		$Node->parentNode()->replaceChild($NewNode, $Node) ;
		$NewNode->appendText($XValue);
     	### $Node->addChild($NewNode);
     	exists $G_CLIParams{D} and WrLog(sprintf("Debug - Update %s with %s",$NewNode->nodePath(),$XValue));
     }
     return 0;
}

sub xmlCreateNode
###############################################################################
#
# Input:	$Xpath
#
# Return:	$Node
#
# Description: Create un bind Node
#
###############################################################################
{
    my $Xpath=shift;
    my ($Result,$Name);
    ## Remove Leading Slash + first Node Name ...
    $Xpath =~ /^[\/]*$/ and return;
    defined $G_CLIParams{D} and WrLog("Debug - Create Node $Xpath");
    $Xpath =~ s/^[\/]?([^\/]+?)([\/\[]|$)/$2/ and $Name=$1;
    unless ( defined $Name )
    {
    	WrLog("Error - Syntax Error requiering Node $Xpath");
    	$G_ErrorCounter++;
    	return;
    }
    ######  Set Value if needed .....
    my @NodeFields= split(/=/,$Name);
    defined $NodeFields[1] and $NodeFields[1] =~ s/(^\")|(\"$)//g ;
    unless ( $NodeFields[0] =~ s/\@// )
    {
    	$Result=XML::LibXML::Element->new($NodeFields[0]);
    	$Result->appendText($NodeFields[1]);
    }  else 
    {
    	$Result = XML::LibXML::Attr->new(@NodeFields);
    }
    ### Check if there is no condition in the path [exp=...]
    defined $G_CLIParams{D} and WrLog("Debug - Check if there is no condition ([]) in the path");
    if ( $Xpath =~ s/\[(.+?)\][\/]?// )
    {
    	$Name=$1;
    	defined $G_CLIParams{D} and WrLog("Debug - create condition Path $Name");
    	$Result->addChild(xmlCreateNode($Name));
    }
    defined $G_CLIParams{D} and WrLog("Debug - Check the Rest Xpath: $Xpath");
    unless ( length $Xpath <= 0 or $Result->findnodes($Xpath) )
    {
    	defined $G_CLIParams{D} and WrLog("Debug - No Path found for $Xpath Create new");
    	$Result->addChild(xmlCreateNode($Xpath));
    }
    defined $G_CLIParams{D} and WrLog(sprintf("Debug - New Node %s have been created ...",$Result->nodePath())); 
    return $Result;
}

sub xmlUpadtePath
###############################################################################
#
# Input:        $root,Xpath,Value
#
# Return:
#
# Description:
#
###############################################################################
{
     my $XmlObj=shift;
     my $Xpath=shift;
     my $XValue=shift;
     my (%TmpAtt,$NewPath,$ExistPath,$Func,$LastParam,@NodesFlag);
     ## defined $G_CLIParams{D} and WrLog("Debug - xmlUpadtePath Input:",$XmlObj->nodePath,$Xpath,$XValue,'-' x 70);
     if ( $Xpath =~ s/\@([^\/\]]+)$// )
     {  ### Update Attribute
     	defined $G_CLIParams{D} and WrLog("Debug - Path is attribute .......");
     	$TmpAtt{$1}=$XValue;
     	$Func=\&xmlSetAttr;
     	$LastParam=\%TmpAtt;
     	$Xpath =~ s/\/$// ;
     } else
     {  ### Update element
     	exists $G_CLIParams{D} and WrLog("Debug - Path is Element .......");
     	$Func=\&xmlSetVal ;
     	### WrLog("-------------------->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>");
     	$LastParam=$XValue;
     }
    my $indx=0;
    defined $G_CLIParams{D} and WrLog("Debug - Validate update type $LastParam ...");
    while ( $#NodesFlag < 0 )
    {
    	if ( $ExistPath =~ s/\[([^\[]+?)\]$// )
    	{
    	   my $TmpStr=$1;
    	   my @SlashCount=split(/\//,$TmpStr) ;
    	   $indx += $#SlashCount;
    	}
    	$Xpath =~ m/(.*)(((^|\/)([^\/]+?)){$indx})$/ or last;
    	$ExistPath=$1;
    	$NewPath=$2;
    	### WrLog(" >>>>>  $ExistPath      ....   $NewPath");  
    	$indx++;
    	@NodesFlag=$XmlObj->findnodes($ExistPath);
    }
    if ( length $NewPath > 0 )
    {
    	defined $G_CLIParams{D} and WrLog("Debug - Add New Element \"$NewPath\"");
       	my $NewNode=xmlCreateNode($NewPath);
    	foreach my $SubNode ( @NodesFlag )
    	{
    	     $SubNode->addChild($NewNode);
    	     ## WrLog(sprintf("Debug - Add Node %s to %s ....",$NewNode->nodePath(),$SubNode->nodePath()));
    	}
    }
    ### defined $G_CLIParams{D} and WrLog("Debug - Update Node/Elemnt Value ....:");
    return $Func->($XmlObj,$Xpath,$LastParam);
}

sub xmlSetting 
###############################################################################
#
# Input:	Array of \%Rec
#
# Return:	0 - O.K , 1 - Error
#
# Description:
#
###############################################################################
{
    my @ArrayRec=@_;
    my %XmlFiles=();
    my $Err=$G_ErrorCounter;
    exists $G_CLIParams{D} and WrLog("Debug - Start manipulating xml Files ...."); 
    foreach my $Rec (@ArrayRec)
    {
    	exists $G_CLIParams{D} and WrLog("Debug - Update xml Parametr $$Rec{Name} ...");
    	exists $$Rec{Value} or WrLog("Info - $$Rec{Name} has no Value. Ignore this parameter"), next;
    	exists $G_CLIParams{D} and WrLog("Debug - Parameter $$Rec{Name} -> \"$$Rec{Value}\"");
    	unless ( exists $XmlFiles{$$Rec{FileName}} )
    	{
    	    my $Parser= XML::LibXML->new();
    	    ### Check if the file exist ...
    	    unless ( -e $$Rec{FileName} )
    	    {
    	    	WrLog("Error - Can Not Find $$Rec{FileName} .Skip update of Parameter \"$$Rec{Name}\"");
    	    	$G_ErrorCounter++;
    	    	next;
    	    }
    	    $XmlFiles{$$Rec{FileName}} = $Parser->parse_file($$Rec{FileName});
    	}
    	$G_ErrorCounter += xmlUpadtePath($XmlFiles{$$Rec{FileName}},$$Rec{Xpath},$$Rec{Value});
    }
    ###  Write To Files 
    while ( my ($FileName,$XmlObj) = each(%XmlFiles) )
    {
    	WrLog("Info - Update File $FileName");
    	$G_ErrorCounter += UpdateFile($FileName,$XmlObj->toString);
    }
    return $G_ErrorCounter-$Err;
}

sub FarmSettings 
###############################################################################
#
# Input:	Array of \%Rec
#
# Return:	0 - O.K , 1 - Error
#
# Description:  set new Farm value at Balancer.conf file:
#		{Farm} = the ini file name
#		{IpList}  = The section name where the parameter should be change.
#
###############################################################################
{
    my @ArrayRec=@_;
    my $Err=$G_ErrorCounter;
    my %BalancerConf=LoadIniFile("/usr/cti/conf/balancer/balancer.conf");
    defined $BalancerConf{FileName} or WrLog("Error - Fail to read/manipulate $BalancerConf{FileName}"), return 1;
    defined $G_CLIParams{D} and WrLog("Debug - Start manipulating Farms at balancer conf ...."); 
    foreach my $Rec (@ArrayRec)
    {
    	defined $$Rec{Value} or WrLog("Info - No Servers found for farm $$Rec{Farm}"),next;
    	WrLog("Info - Update Farm $$Rec{Farm}");
    	$Err += SetSection(\%BalancerConf,"farm=$$Rec{Farm}","port",$$Rec{Port});
    	#####  UpDate the new Ips
    	my @NewContent=();
    	my $Counter=0;
    	defined $G_CLIParams{D} and WrLog("Debug - Update Farm $$Rec{Farm} with $$Rec{Value}");
    	foreach my $IpNum (split(/[;,]+/,$$Rec{Value}) )
    	{
    	    $Counter++;
    	    $IpNum =~ s/:/,A,/ or $IpNum .= ",A," ;
    	    push(@NewContent,"server$Counter=$IpNum");
    	}
    	### Go Over the section and save all nonserver parameters
    	my $OrigContent=$BalancerConf{Content};
    	defined $G_CLIParams{D} and WrLog("Debug - $BalancerConf{$$Rec{Farm}}");
    	my ($FarmStart,$FarmEnd)=@{$BalancerConf{"farm=$$Rec{Farm}"}};
    	for ( my $LineNo=$FarmStart ; $LineNo <= $FarmEnd ; $LineNo++ )
    	{
    	    $$OrigContent[$LineNo] =~ /server/i or push(@NewContent,$$OrigContent[$LineNo]);
    	}
    	
    	unshift(@NewContent,@$OrigContent[0..$FarmStart-1]);
    	push(@NewContent,@$OrigContent[$FarmEnd+1..$#$OrigContent]);
    	$BalancerConf{Content}=\@NewContent;
    	$Err += ParseSections(\%BalancerConf);
    }
    defined $G_CLIParams{D} and WrLog("Debug - Update Balancer configuration file ...");
    $G_ErrorCounter - $Err or UpDateIniFile(\%BalancerConf);
    return $G_ErrorCounter - $Err ;
}

sub IniSettings 
###############################################################################
#
# Input:	Array of \%Rec
#
# Return:	0 - O.K , 1 - Error
#
# Description:  set new value($Value) to IniFile Parameter. %Rec content:
#		{FileName} = the ini file name
#		{SecName}  = The section name where the parameter should be change.
#		{ParamName} = The Parameter name in the sction.
#
###############################################################################
{
    my @ArrayRec=@_;
    ## my $RecP=shift;
    my %IniFiles=();
    my $Err=$G_ErrorCounter;
    defined $G_CLIParams{D} and WrLog("Debug - Start manipulating ini Files ...."); 
    foreach my $Rec (@ArrayRec)
    {
    	defined $G_CLIParams{D} and WrLog("Debug - Manipulating $$Rec{Name}");
    	defined $$Rec{Value} or WrLog("Info - Parameter $$Rec{Name} has no Value. Ignore this parameter"),next;
    	unless ( defined $IniFiles{$$Rec{FileName}} )
    	{
    	    my %IniRec=LoadIniFile($$Rec{FileName});
    	    defined $IniRec{FileName} or WrLog("Error - Fail to read/manipulate $$Rec{FileName}"), next;
    	    $IniFiles{$$Rec{FileName}}=\%IniRec;
    	}
    	defined $G_CLIParams{D} and WrLog("Debug - Parametr $$Rec{ParamName} value - $$Rec{Value}");
    	$G_ErrorCounter += SetSection($IniFiles{$$Rec{FileName}},$$Rec{SecName},$$Rec{ParamName},$$Rec{Value});
    }
    defined $G_CLIParams{D} and WrLog("Debug - Start writing Ini Files ...");
    
    while ( my ($File,$IniRec) = each(%IniFiles) )
    {
    	WrLog("Info - Update Ini file $$IniRec{FileName}");
    	$G_ErrorCounter += UpDateIniFile($IniRec);
    }
    return $G_ErrorCounter - $Err ;
}

sub UpDatetxt
###############################################################################
#
# Input:	\@Content,\%TxtRec
#
# Return:	0 - O.K , 1 - Error
#
# Description:
#
###############################################################################
{
    my $Content=shift;
    my $TxtRec=shift;
    my %TxtOp=('s' => '=' );
    my $UnChange=1;
    my $Err=0;
    my ($NewVal,$Tune);
    ### ToDo Parse Operands ...
    $$TxtRec{Op} =~ s/(^\[)|(\]$)//g ;
    while ( $$TxtRec{Op} =~ s/^([ablvsr])(\S+|.)\s*// )
    {
    	$TxtOp{$1}=$2;
    	defined $G_CLIParams{D} and WrLog("Debug - Insert Option $1 => \"$2\"");
    }
	$TxtRec->{ParamName} or $TxtOp{r} or WrLog("Error - incorrect Parameter Definition of $TxtRec->{Name}") , return 1;
    my $Tune=0;
    my $Triger = $TxtRec->{ParamName} ;
	## $Triger or $Triger = exists $TxtOp{r} ? $TxtOp{r} : $TxtRec->{ParamName} ;
    my %TrigerPlace ;###  = ( $TxtRec->{ParamName}  => [] );
    exists $TxtOp{b} and $TrigerPlace{$TxtOp{b}} = [];
    exists $TxtOp{a} and $TrigerPlace{$TxtOp{a}} = [] ;
	exists $TxtOp{r} and $TrigerPlace{$TxtOp{r}} = [] ;
    my $Musck = join('|',keys(%TrigerPlace));
	$TrigerPlace{$TxtRec->{ParamName}}=[];
    for ( my $Indx=0; $Indx <= $#$Content ; $Indx++ )
    {
		if ( $Content->[$Indx] =~ /($Musck)/ )
		{
			push(@{$TrigerPlace{$1}},$Indx);
			exists $G_CLIParams{D} and WrLog("Debug - Find $1 at Line $Indx");
		}
		$Content->[$Indx] =~ /(^|\s)($Triger)(\s|$TxtOp{s}|$)/ or next ;
    	push(@{$TrigerPlace{$2}},$Indx);
    	exists $G_CLIParams{D} and WrLog("Debug - Find Parameter $2 at Line $Indx");
    }
    
	my ($MatcLine,$NextLine,$LastLine);
	if ( exists $TxtOp{r} )
	{
		my $Index= length ($TxtRec->{ParamName}) > 0 ? $TxtRec->{ParamName} : $TxtOp{r} ;
		foreach $MatcLine ( @{$TrigerPlace{$Index}} )
    	{
    	 	    $Content->[$MatcLine]=~ s/$TxtOp{r}/$TxtRec->{Value}/;
    	} 
		return $Err ;
	}
    $Triger=$TxtRec->{ParamName};
    if ( $#{$TrigerPlace{$Triger}} < 0 )
    {   ### Parameter not exist at file add it to file
        exists $G_CLIParams{D} and WrLog("Debug - Parameter $Triger not exist at file create new one.");
    	if ( exists $TxtOp{a} and $#{$TrigerPlace{$TxtOp{a}}} >=0 )
    	{
    	    $MatcLine=$TrigerPlace{$TxtOp{a}}->[-1];
    	    exists $G_CLIParams{D} and WrLog("Debug - Add $$TxtRec{ParamName} at Line $MatcLine");
    	    
    	} elsif ( exists $TxtOp{b} and $#{$TrigerPlace{$TxtOp{b}}} >=0 )
    	{
    	    $MatcLine=$TrigerPlace{$TxtOp{a}}->[-1]-1;
    	    exists $G_CLIParams{D} and WrLog("Debug - Add $$TxtRec{ParamName} at Line $MatcLine");
    	} else
    	{
    	    $MatcLine=$#$Content + 1;
    	}
    	my $NewLine="$$TxtRec{ParamName}$TxtOp{s}$$TxtRec{Value}";
    	$LastLine=$#$Content;
    	$NextLine=$MatcLine+1;
    	if ( $MatcLine < 0 )
    	{
    	   unshift(@$Content,$NewLine);
    	} elsif ( $NextLine > $LastLine )
    	{
    	     push(@$Content,$NewLine);
    	} else
    	{
    	   my @NewContent=(@$Content[0-$MatcLine],$NewLine,@$Content[$NextLine-$LastLine]);
    	   @$Content=@NewContent;
    	}
    } else
    {   ## Parameter already exists at file
        $MatcLine=$TrigerPlace{$Triger}->[-1];
        exists $G_CLIParams{D} and WrLog("Debug - update $Triger at Line $MatcLine.");
        if ( exists $TxtOp{v} )
        {
        	$$Content[$MatcLine]=~/^(.*?$Triger\s*$TxtOp{s}\s*)(\S.+|$)/ ;
        	$NextLine = $1;
        	$LastLine = $2 ; 
        	my @ValList=split(/$TxtOp{v}/,$LastLine);
        	unless ( grep(/^$$TxtRec{Value}$/,@ValList) )
        	{
        	     $LastLine= exists $TxtOp{l} ? "$LastLine$TxtOp{v}$$TxtRec{Value}" : "$$TxtRec{Value}$TxtOp{v}$LastLine" ;
        	     $$Content[$MatcLine]="$NextLine$LastLine";
    	        }
    	 }  else
    	 {
    	      ## $$Content[$MatcLine]=~s/($Triger\s*$TxtOp{s}\s*)(\S.+|$)/$1$$TxtRec{Value}/ ; 
			  ## Fix For PSG00671104
			  $$Content[$MatcLine]=~s/($Triger\s*)($TxtOp{s}|$)(.+|$)/$1$TxtOp{s}$$TxtRec{Value}/ ;
    	 }
    }
    return $Err;
}

sub txtSettings 
###############################################################################
#
# Input:	Array of \%Rec
#
# Return:	0 - O.K , 1 - Error
#
# Description:  set new value($Value) to Txt File Parameter. %Rec content:
#		{FileName} = the txt file name
#		{Op}  = .
#		{ParamName} = The Parameter name in the sction.
#		{Value} = 
#
###############################################################################
{
    my @ArrayRec=@_;
    my %TxtFiles=();
    my $Err=$G_ErrorCounter;
    defined $G_CLIParams{D} and WrLog("Debug - Start manipulating Text Files ...."); 
    foreach my $Rec (@ArrayRec)
    {
    	defined $G_CLIParams{D} and WrLog("Debug - Manipulating $$Rec{Name}");
    	defined $$Rec{Value} or WrLog("Info - Parameter $$Rec{Name} has no Value. ignore this parameter"),next ;
    	unless ( defined $TxtFiles{$$Rec{FileName}} )
    	{
    	    my $Flag=$G_ErrorCounter;
    	    my @Content=ReadFile($$Rec{FileName});
    	    $G_ErrorCounter > $Flag and WrLog("Error - Fail to read $$Rec{FileName}"), next;
    	    $TxtFiles{$$Rec{FileName}}=\@Content;
    	}
    	defined $G_CLIParams{D} and WrLog("Debug - set $$Rec{ParamName} to \"$$Rec{Value}\"");
    	$G_ErrorCounter += UpDatetxt($TxtFiles{$$Rec{FileName}},$Rec);
    }
    
    while ( my ($File,$TxtCont) = each(%TxtFiles) )
    {
    	$#$TxtCont >= 0 or WrLog("Warning - $File content is empty skip File update."),next;
    	WrLog("Info - Update Text File $File");
    	$G_ErrorCounter += UpdateFile($File,@$TxtCont);
    }
    return $G_ErrorCounter - $Err ;
}

sub cmdSettings # Value,
###############################################################################
#
# Input:	Array of \%Rec
#
# Return:	0 - O.K , 1 - Error
#
# Description:  CmdName;;;CLIParams
#
###############################################################################
{
    my @ArrayRec=@_;
    my @CmdList;
    defined $G_CLIParams{D} and WrLog("Debug - Start Running scripts commands ...");
    foreach my $Rec (@ArrayRec)
    {
    	push(@CmdList,"$$Rec{CmdName} $$Rec{CLIParams}");
    }
    ## defined $G_CLIParams{D} and WrLog("Debug - Aboute to run:",@CmdList,"","");
    return RunCmds(@CmdList);
}

sub getUnit
{
    exists $G_CLIParams{Unit} and return $G_CLIParams{Unit};
    length( $_ ) > 1 and return $_;
    my $FileName="/usr/cti/conf/babysitter/Babysitter.ini";
    my %BabysitterConf=LoadIniFile($FileName);
    my %Params=ReadSections(\%BabysitterConf,"General");
    return $Params{UnitType};
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
my (%Configuration,%CLIOctParams,%TmpOctopusParams,%TmpIniRec);

### Start to load all Configuration Files
foreach my $ConfFile ( split(/,/,$G_CLIParams{Conf}) )
{
	%TmpIniRec=LoadIniFile($ConfFile);
	if ( %Configuration )
	{
		WrLog("Info - Merge configuration of $TmpIniRec{FileName}");
		foreach my $SecName ( keys(%TmpIniRec) )
		{
			($SecName eq "FileName" or $SecName eq "Content") and next;
			$G_ErrorCounter += SetSection(\%Configuration,$SecName,ReadSections(\%TmpIniRec,$SecName));
		}
	} else
	{
		%Configuration=%TmpIniRec;
	}
}
%CLIOctParams=%G_CLIParams;
foreach ("Conf","LogFile","D","Unit")
{
	delete $CLIOctParams{$_};
}
## Update Parameters from command line
$G_ErrorCounter += SetSection(\%Configuration,"Values",%CLIOctParams);
%TmpOctopusParams=ReadSections(\%Configuration,"Values");
my $Unit=getUnit($TmpOctopusParams{Unit});
my %RealConfList=exists $Configuration{"Octopus.Parameters.Mapping"} ? ParamsMapping(\%Configuration) : () ;

unless ( $G_ErrorCounter )
{
    #### Update values with the new mapping values
    WrLog("Info - Start Update all Relevant Parameters for Unit $Unit");
    $G_ErrorCounter += SetSection(\%Configuration,"Values",%RealConfList);
    ###  %TmpOctopusParams=ReadSections(\%Configuration,"Values");
    $G_ErrorCounter += ParamsSettings(\%Configuration,$Unit)
}
my $ErrMessage= $G_ErrorCounter ? "Finish with ERRORS see Log File $G_CLIParams{LogFile}"
		: "F I N I S H - S U C C E S S F U L L Y  :-)";
EndProg($G_ErrorCounter,$ErrMessage);