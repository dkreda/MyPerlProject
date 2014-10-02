#!/usr/local/bin/perl


###########
# Modules #
###########
use strict;
use warnings;
use Win32::OLE qw(in with);
use Win32::OLE::Const 'Microsoft Excel';
use Spreadsheet::ParseExcel;

use Switch;
use Log::Log4perl qw(get_logger);
use XML::LibXML;
use English;


##########
# Consts #
##########
#$Win32::OLE::Warn = 3;
my $NewXML = "New_ProfileDefinitions_InSight.xml" ;
my $Fieldxpath = '//Provisioning/ProfileDefinition/Entities/Entity/Fields/Field';
my $Collxpath = '//Provisioning/ProfileDefinition/Entities/Entity/Collections/Collection/CollectionElement';
my $LOGGER_CONF = q(
					log4perl.rootLogger					= INFO, FileApp, ScreenApp
					log4perl.appender.FileApp				= Log::Log4perl::Appender::File
					log4perl.appender.FileApp.filename			= log/ConvertXls.log
					log4perl.appender.FileApp.layout			= PatternLayout
					log4perl.appender.FileApp.layout.ConversionPattern	= %d [%p] [%F{1}:%L %M] - %m%n

					log4perl.appender.ScreenApp				= Log::Log4perl::Appender::Screen
					log4perl.appender.ScreenApp.stderr			= 0
					log4perl.appender.ScreenApp.layout			= PatternLayout
					log4perl.appender.ScreenApp.layout.ConversionPattern	= %m%n
				);


  
	
######################
###  Variables		##
######################
my $ExcelConvert_VER ;
my $source_excel ;
my $parse_excel;
my $sheets;
my $ExcelFile ;
my $CurrentXML ;

my $dbData;
my %attr = (); #Hash to save attribute's data from xls

Log::Log4perl->init(\$LOGGER_CONF);
my $logger = get_logger();


###########
# Modules #
###########

sub getWorksheetList
{
	my $ArgsSize=@ARGV;
	if ( $ArgsSize < 3 )
	{
		#### Try to get the Worksheet List from the profileDef filename ####
		my %FileMap = ( "ProfileDefinitions_InSight"	=> [] ,
						"ProfileDefinitions_WHC"		=> [] ,
						"ProfileDefinitions_VVM"		=> [] ,
						"ProfileDefinitions_MMG"		=> [] );
	    my $MapName=$CurrentXML;
		$MapName =~ s/.xml//i ;
		unless ( exists $FileMap{$MapName} )
		{
			$logger->error("I Can not determine which workshheet to use for \"$MapName\"");
			die "Fail to dtermine which Workshheet to use see log ...";
		}
		return @{$FileMap{$MapName}} ;
	} else
	{
		$ArgsSize--;
		return @ARGV[2..$ArgsSize] ;
	}
}

sub startConvert 
{
	if ( @ARGV < 2 ) {
           $logger->error("ERROR - [USAGE]: $0 [xls file] [current ProfileDefinition_InSight.xml] [WorkSheets ....]" ) ;
           exit 1;
    } else {

		$ExcelFile  = $ARGV[0];
		$CurrentXML = $ARGV[1];
		
		unless ( -e $ExcelFile ) { $logger->error("file $ExcelFile not exist "); exit 1;} 
		unless ( -e $CurrentXML ) { $logger->error("file $CurrentXML not exist "); exit 1;} 
		my $FullPath = $CurrentXML ;
		$CurrentXML =~ /[\\\/]?([^\\\/]+?)$/ ;
		$NewXML=$1 ;
		$FullPath =~ s/[\\\/][^\\\/]+?$// or $FullPath=".";
		$NewXML = $FullPath . "/New_" . $NewXML ;
		$logger->info("Start merge data from  $ExcelFile file and  $CurrentXML file into $NewXML file." );
	} #if

}


sub ProfDefParser
{
    my $parser = XML::LibXML->new();
    my $tree;
    my @fields;
	my @collections;

	my $type;
	my $len;

	my @db_name;
	my @table_name;
	my $db_text;
	my %check;


    eval {
            $tree = $parser->parse_file($CurrentXML);
    };

    if ($@) {
             $logger->error("ERROR: Parsing $CurrentXML file failed: $@ $!");
			 exit 1;
    }

    my $root = $tree->getDocumentElement();

	############################################################################
	#Get all <Field> elements and add db data
	@fields = $root->findnodes($Fieldxpath);
	if(! @fields)
	{
		$logger->error("ERROR: No <Field> element found in $CurrentXML");
		exit 1;
	}

	foreach my $field (@fields)
	{
		my @attributes = $field->findnodes('.//DsvName');
		if (scalar(@attributes) > 0 )
		{
			my $name = $attributes[0]->textContent;
			$check{$name} = $name;
			if (defined $attr{$name}) 
			{
				$type = $attr{$name}->{'Type'};
				$len = $attr{$name}->{'Length'};

				#Add <dbData> element
				$dbData = $tree->createElement('DbData');
				$dbData->appendTextChild( "DbType" ,$type );
				if (defined($len)) {
					$dbData->appendTextChild( "DbLength" ,$len );
				}		
				$field->appendChild($dbData);


				#If db name should be updated
				@db_name = $field->findnodes('.//DbName/text()');
				$db_text = $db_name[0]->data;  
				@table_name = split(/\./, $db_text); 
				if ((uc $table_name[1]) ne (uc $attr{$name}->{'dbName'})) 
				{
					$db_text = $table_name[0] . '.' . $attr{$name}->{'dbName'};
					$db_name[0]->setData($db_text);
				}
				
				
				#If defined default add it to <SystemDefaults> element
				if (defined($attr{$name}->{'Default'} )) 
				{
					my @defaults = $field->findnodes('./SubscriberBehavioralInfo/ResolvedLevels/SystemDefaults');
					if (scalar(@defaults) > 0) 
					{
						my @def_values = split(/\,/,$attr{$name}->{'Default'}); 
						my $string;
						my $first = 1;
						foreach my $value (@def_values) 
						{
							chomp($value);
						    $value =~ s/^\s+//;
						    $value =~ s/\s+$//;
							if ((scalar(@def_values) < 1 ) || $first == 1) {
								$string = $value;
								$first  = 0;
							}
							else {
								$string = $string . '|' . $value;
							}
							
						}
						$defaults[0]->appendTextChild("DefaultValue", $string) ;
					}
					else { print "$name does not have <SystemDefaults>\n";}
				}

			} # if defined attr($name)
		} #if exists <DsvName>

	} #Fore fields

	#################################################################
	#Go throught Collection's fields
	@collections = $root->findnodes($Collxpath);
	if(! @collections)
	{
		$logger->info("NOTE: No <Collection> element found in $CurrentXML");
	}
	
	my $table_name;
	foreach my $collection (@collections)
	{
		#get table name from xml
		my @text = $collection->findnodes('.//DsvEntityName/text()');
		if (scalar(@text) > 0) {
			$table_name = $text[0]->data; 
		}

		my @col_fields = $collection->findnodes('./Fields/Field');
		foreach my $col_field (@col_fields) 
		{
			my @attributes = $col_field->findnodes('.//DsvName');
			if (scalar(@attributes) > 0 )
			{
				my $attr_name = $attributes[0]->textContent;
				my $name; 
				if ($table_name) {
					$name = $table_name . '.' . $attr_name; 
				}
				else {
					$name = $attr_name; }
				
				$check{$name} = $name;
				if (defined $attr{$name}) 
				{
					$type = $attr{$name}->{'Type'};
					$len = $attr{$name}->{'Length'};

					$dbData = $tree->createElement('DbData');
					$dbData->appendTextChild( "DbType" ,$type );
					if (defined($len)) {
						$dbData->appendTextChild( "DbLength" ,$len );
					}
					
					$col_field->appendChild($dbData);

					#Updtae db name 
					@db_name = $col_field->findnodes('.//DbName/text()'); 
					$db_name[0]->setData( $attr{$name}->{'dbName'});

					#If defined default add it to <SystemDefaults> element
					if (defined($attr{$name}->{'Default'} )) 
					{ 
						my @defaults = $col_field->findnodes('./SubscriberBehavioralInfo/ResolvedLevels/SystemDefaults');
						if (scalar(@defaults) > 0) 
						{ 
							my @def_values = split(/\,/,$attr{$name}->{'Default'}); 
							
							foreach my $value (@def_values) 
							{
								chomp($value);
								$value =~ s/^\s+//;
								$value =~ s/\s+$//;
								$defaults[0]->appendTextChild("DefaultValue", $value) ;
							}						
						}
						else { print "$name does not have <SystemDefaults>\n";}
					}

				} # if defined attr($name)
			} #if exists <DsvName>
	  } #fore each collection field
	}# fore each collection

	
	########### Print attributes from xls which does not exist in xml
	print "\nXXXXXXXXXXXX\n";
	print "Attributes from XLS which do not exist in xml: \n";
	foreach my $nname (keys %attr) {
		if (!defined $check{$nname}) {
			print "$nname\n";
		}
	 }
	
	$tree->toFile($NewXML,1);
}


sub readXLS
{
	my $MinRow = 2;
	my $MaxRow;
	my $attr_col;
	my $type_col;
	my $len_col;
	my $sysdef_col;
	my $nill_col;
	my $name_col;

	my $col;
	my $attrName;
	my $dbType;
	my $dbLength;
	my $default;
	my $nillable;
	my $table_name;
					# $attr_col,$name_col,$type_col,$len_col,$nill_col,$sysdef_col
	my %ColLocation = ( "IS4 Subscriber"			=>  [1,2,4,5,11,12] ,
						"Subscriber-related tables"	=>  [0,1,3,4,10,11] ,
						"VVM Subscriber"			=>  [0,1,3,4,9,11] ,
						"VM2MMS Subscriber"			=>  [0,1,3,4,9,11] ,
						"VW Subscriber"				=>	[0,1,3,4,9,11] ,
						"WHC-NFM Subscriber"		=>	[0,1,3,4,9,11] ,
						"InSight related MIPS"		=>	[0,1,3,4,13,11] );

	# get already active Excel application or open new
	my $Excel = Win32::OLE->GetActiveObject('Excel.Application')
		|| Win32::OLE->new('Excel.Application', 'Quit');  


	#Parsing the Excel file
	$source_excel = Spreadsheet::ParseExcel->new();
	$parse_excel = $source_excel->parse($ExcelFile) ;
	defined $parse_excel or die "Could not open source Excel file $ExcelFile ($parse_excel): $!" , $source_excel->error();
	
		
	#Read sheets	
	foreach my $worksheet (getWorksheetList()) 
	{
		exists $ColLocation{$worksheet} or $logger->error("Error - Worksheet $worksheet is not supported yet ..."), exit 1;

		 my $source_sheetSub = $parse_excel->Worksheet($worksheet);
		 
		 next unless defined $source_sheetSub->{MaxRow};
		 next unless $source_sheetSub->{MinRow} <= $source_sheetSub->{MaxRow};
		 next unless defined $source_sheetSub->{MaxCol};
		 next unless $source_sheetSub->{MinCol} <= $source_sheetSub->{MaxCol};
		 		 
		 $logger->info("Sheet $worksheet");
		 $attr_col = $ColLocation{$worksheet}->[0] ;
		 $name_col = $ColLocation{$worksheet}->[1] ;
		 $type_col = $ColLocation{$worksheet}->[2] ;
		 $len_col  = $ColLocation{$worksheet}->[3] ;
		 $nill_col = $ColLocation{$worksheet}->[4] ;
		 $sysdef_col=$ColLocation{$worksheet}->[5] ;
		 
		 print "Max: $source_sheetSub->{MaxRow}\n";
		 foreach my $row_index ( $MinRow .. $source_sheetSub->{MaxRow})
		 {
			if ($source_sheetSub->{Cells}[$row_index][$attr_col]) {
			
				$attrName = $source_sheetSub->{Cells}[$row_index][$attr_col]->value();
				chomp($attrName);
				$attrName =~ s/^\s+//;
				$attrName =~ s/\s+$//; 

				if ( $attrName =~ / table/) 
				 {
					 my @table_name = split (/table/,$attrName);
					 $table_name = uc $table_name[0];
					 $table_name =~ s/\s+$//; 
					 next();
				 }

				#Get db name
				my $dbName = $source_sheetSub->{Cells}[$row_index][$name_col]->value();
				chomp($dbName);
				$dbName =~ s/^\s+//;
				$dbName =~ s/\s+$//; 
				
				#Get db type
				$dbType = $source_sheetSub->{Cells}[$row_index][$type_col]->value();
				chomp($dbType);
					  
				if ( $dbType =~ /Mandatory/ ) {
					#my @Type = split(/multi/,$dbType );	
					#$dbType = $Type[0];
					$dbType = 'Number';
				}

				chomp($dbType);
				$dbType =~ s/^\s+//;
				$dbType =~ s/\s+$//;

				#Get db length
				$dbLength = $source_sheetSub->{Cells}[$row_index][$len_col]->value();
				chomp($dbLength);
				$dbLength =~ s/^\s+//;
				$dbLength =~ s/\s+$//;

				if ($worksheet eq 'Subscriber-related tables') { 
					$dbName = $table_name . '.' . $dbName; 
					$attrName = $table_name . '.' . $attrName; 
				}
				
				#Get System defaults
				$col = $source_sheetSub->{Cells}[$row_index][$sysdef_col];
				if ($col) {
					$default = $col->value();
					if ($default ne "") {
						chomp($default);
						$default =~ s/^\s+//;
						$default =~ s/\s+$//;

						if ( $default ne "?") {
							$attr{$attrName}->{'Default'} = $default;
						}
					} 
				}

				$attr{$attrName}->{'Type'} =  $dbType;
				$attr{$attrName}->{'dbName'} = $dbName;
				if ($dbLength) {
					$attr{$attrName}->{'Length'} = $dbLength;
				}	
			} # if coll

		 } #fore rowindex
	} #fore worksheets
		
}






#######################
####   Main      ######
#######################
BEGIN {
	$ExcelConvert_VER = 1.00;
	
	# Logger init #####################################
	#Log::Log4perl->init("log\\log.conf");
	#$logger = Log::Log4perl->get_logger("Convert");
}


startConvert();
readXLS();
ProfDefParser();


END {}
