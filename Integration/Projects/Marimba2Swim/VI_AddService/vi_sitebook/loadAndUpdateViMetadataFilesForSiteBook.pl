#!/usr/bin/perl
#Create by Lior Yosef
#Date: 3/9/2010
#Version 3.0.0.0

###########
# Modules #
###########
use warnings;
use strict;
use English;
use Net::SSH::Perl;
use XML::LibXML;
use Net::SFTP;
use Net::SFTP::Constants qw(
    SSH2_FILEXFER_ATTR_PERMISSIONS
    SSH2_FILEXFER_VERSION );
use Net::SFTP::Attributes;
use Log::Log4perl qw(get_logger);
use File::Glob ':glob';

################
# Global Conts #
################
my @SUPPORTED_UNITS = ('CAS', 'Proxy_AU', 'MTS');
my $METADATA_REMOTE_DIRECTORY = '/usr/cti/conf/sitebook';
my $SCDB_SERVER = 'snmpmanager';
my $SCDB_REMOTE_FILE = '/opt/CMVT/scdb/data/scdb.xml';
my $SCDB_NEW_FILE = '/tmp/scdb.xml';
my $SMU_USERNAME = $ARGV[0];
my $SMU_PASSWORD = $ARGV[1];
my $SBUSER = $ARGV[2];
my $SBPASSWORD = $ARGV[3];
my $INSTALLATION_AUDIT_LOG_FILE = "./$0.log";
my $LOGGER_CONF = "./$0.conf";
my $TMP_WORD_DIR = './viMetaDataFiles';
my $IS4_PARAMETERS_FILE = '/etc/cns/params/IS4_Installation_parameters';
my $SITEBOOK_LOCAL_SCRIPT = './IS4_SiteBook_Customization2.pl';
my $SITEBOOK_REMOTE_SCRIPT = './IS4_SiteBook_Customization2.pl';

####################
# Golbal Variables #
####################
my @listOfUnits;
my $warnings = 0;
my %supportedUnits;
my %supportedUnitTypes;
my $logger = get_logger();
my $exitStatus;
my $output;
my $sysDomain;
my @listOfMetadaFiles;
my $metaDataLocalDirectory;

##############
# Prototypes #
##############
sub parseScdb($);
sub getFiles($$$$$);
sub sendFiles($$$$$);
sub changeMode($$);
sub executeSiteBookScript($$$$$);
sub sendFile($$$$$);
sub getFile($$$$$);

################
# Subroutines  #
################
sub parseScdb($)
{
	my ($file) = @_;
	my $parser;
	my $doc;
	my $root;
	my @node;
	my $Xpath = "//Object[\@objectClass=\"Unit_Type\"]";
	my @attr;
	my @list;
	my @listOfHosts;
	#objectName

	#Loading XML file
	$parser = XML::LibXML->new();
	$doc = $parser->parse_file($file); #HANDLE parsing exception
	$root = $doc->documentElement();

	@node = $root->findnodes($Xpath);
	if(! @node)
	{
		$logger->error("Cannot find the any Unit_Type in $file");
		exit(4);
	}

	foreach my $node (@node)
	{
		$Xpath = '@objectName';
		@attr = $node->findnodes($Xpath);
		if (! @attr)
		{
			$logger->error("Cannot find any objectName in ".$node->getValue());
			next();
		}
		foreach my $unitTypes (@attr)
		{
			$unitTypes = $unitTypes->getValue();
			$unitTypes =~ s/_Unit$//;
			$logger->debug("Unit type is $unitTypes");
			if (! grep(/^$unitTypes$/, @SUPPORTED_UNITS))
			{
				$logger->debug("Unit type $unitTypes is not supported");
				next();
			}
			$Xpath = 'UnitInstance/@UnitName';
			@listOfHosts = $node->findnodes($Xpath);
			if (! @listOfHosts)
			{
				$logger->info("No units found for $unitTypes");
				next();
			}
			foreach my $host (@listOfHosts)
			{
				$host = $host->getValue();
				$logger->debug("host found: $host");
				push(@list, $host);
				$logger->debug("Unit Type is unitTypes");
				$supportedUnitTypes{$host}=$unitTypes;
			}
		}
	}

	return(@list);
}

sub getFiles($$$$$)
{
	my ($server, $user, $pass, $source, $target) = @_;
	my %sftpArgs;
	my $sftp;
	my $passChar = "*" x length($pass);
	my $err;
	my @listOfFiles;

	#Configure sftp user/password/port
	%sftpArgs = (user => $user,
		password  =>  $pass,
		ssh_args  =>  [port=>22]);

	#Cleanup SSH key (just in case that Net::SFTP doesn't how to handle when key changed)
	$logger->debug("Removig ".$ENV{'HOME'}."/.ssh");
	`rm -rf $ENV{'HOME'}/.ssh`;

	eval
	{
		#Connect
		$logger->debug("Connecting to server; $server with the following arguments: user-> $user, password-> $passChar"); 
		$sftp = Net::SFTP->new($server,%sftpArgs);
		#Listint all files in $source directory
		$logger->debug("Listing remote files on $source directory");
		$sftp->ls($source , sub {
											push (@listOfFiles,$_[0]->{filename})
										});
		if (! @listOfFiles)
		{
			$logger->error("No files found in $server:$source");
			return(2);
		}
		$logger->debug("The following files found: @listOfFiles");
		$logger->debug("Getting all files");
		foreach my $file (@listOfFiles)
		{
			if (-d $file)
			{
				#File is directory...moving to next one
				$logger->debug("$file is a directory. Movint to next file");
				next();
			}
			$logger->debug("SFTP: Get $source/$file into $target/$file");
			$sftp->get("$source/$file", "$target/$file");
		}
	};
	$err = $@;

	if ($err)
	{
		$logger->error("$err");
		return(1);
	}

	return(0);
}

sub sendFiles($$$$$)
{
	my ($server, $user, $pass, $source, $target) = @_;
	my %sftpArgs;
	my $sftp;
	my $passChar = "*" x length($pass);
	my $err;
	my @listOfFiles;
	my $exitStatus;
	my $output;
	my @parse;

	#Configure sftp user/password/port
	%sftpArgs = (user => $user,
		password  =>  $pass,
		ssh_args  =>  [port=>22]);

	#Cleanup SSH key (just in case that Net::SFTP doesn't how to handle when key changed)
	$logger->debug("Removig ".$ENV{'HOME'}."/.ssh");
	`rm -rf $ENV{'HOME'}/.ssh`;

	eval
	{
		#Connect
		$logger->debug("Connecting to server; $server with the following arguments: user-> $user, password-> $passChar"); 
		$sftp = Net::SFTP->new($server,%sftpArgs);
		#Listint all files in $source directory
		$logger->debug("Listing local files from $source directory");
		@listOfFiles=bsd_glob("$source/*");
		$logger->debug("The following files found: @listOfFiles");
		$logger->debug("Sending all files");
		foreach my $file (@listOfFiles)
		{
			if (-d $file)
			{
				#File is directory...moving to next one
				$logger->debug("$_ is a directory. Movint to next file");
				next();
			}
			@parse = split(/\//, $file);
			$logger->debug("SFTP: Put $file into $target/$parse[-1]");
			$sftp->put($file, "$target/$parse[-1]");
		}
	};
	$err = $@;

	if ($err)
	{
		$logger->error("$err");
		return(1);
	}

	return(0);
}

sub changeMode($$)
{
	my ($mode, $filename) = @_;
	my $counter;

	$logger->debug("Setting mode of $mode to $filename");
	$counter = chmod $mode,$filename;

	if (! $counter)
	{
		$logger->error("Failed to set mode $mode to $filename");
	}

	return(0);
}

sub executeSiteBookScript($$$$$)
{
	my ($host, $user, $pass, $sysDomain, $metaDataFiles) = @_;
	my $cmd = "env perl $SITEBOOK_REMOTE_SCRIPT $sysDomain";
	my $ssh;
	my $stdout;
	my $stderr;
	my $exit;
	my $passChar = "*" x length($pass);
	my $err;
	my $tmpCmd;
	my @parse;

	eval
	{
		$logger->debug("Connecting to $host");
		$ssh = Net::SSH::Perl->new($host);
		$logger->debug("Login using user-> $user and pass: $passChar");
		$ssh->login($user, $pass);

		foreach my $file (@{$metaDataFiles})
		{
			if (-d $file)
			{
				$logger->debug("$file is directory. Moving to next");
				next();
			}

			@parse = split(/\//, $file);
			$file = $parse[-1];
			#$file = $METADATA_REMOTE_DIRECTORY.'/'.$file;
			$tmpCmd = $cmd.' '.$file;
			$logger->debug("Using ssh->cmd command to execute the following command: $tmpCmd");
			($stdout, $stderr, $exit) = $ssh->cmd($tmpCmd);
			if ($exit)
			{
				die $stdout;
			}
		}
	};
	$err = $@;
	if ($err)
	{
		$logger->debug($err);
		return(1,$err);
	}

	if ($stderr)
	{
		chomp($stderr);
		$logger->debug("STDERR of $tmpCmd is: $stderr");
	}
	else
	{
		$stderr = '';
	}

	if ($exit)
	{
		$logger->error("The cmd '$tmpCmd' exit with $exit status and the following error: $stderr");
		return($exit,$stderr);
	}

	return(0,$stdout);
}

sub readSysDomain()
{
	my @data;
	my @output;
	my $unit;
	my @parse;


	open (PARAM, "<", $IS4_PARAMETERS_FILE) or do
	{
		$unit = "Failed to open: $IS4_PARAMETERS_FILE: $!";
		$logger->error("$unit");
		exit(14);
	};
	@data = <PARAM>;
	chomp(@data);

	@output = grep(/^Global_DNSDomain=/, @data);
	if (! @output)
	{
		$unit = "Global_DNSDomain parameter doesnt exists in $IS4_PARAMETERS_FILE";
		$logger->error("$unit",'error');
		exit(15);
	}

	$output[0] =~ s/.+=//;
	@parse = split(/\./, $output[0], 2);
	$unit = $parse[1];

	return($unit);
}

sub sendFile($$$$$)
{
	my ($server, $user, $pass, $source, $target) = @_;
	my %sftpArgs;
	my $sftp;
	my $passChar = "*" x length($pass);
	my $filesPermission = 0777;
	my $attrs;
	my $err;

	#Configure sftp user/password/port
	%sftpArgs = (user => $user,
		password  =>  $pass,
		ssh_args  =>  [port=>22]);

	#Cleanup SSH key (just in case that Net::SFTP doesn't how to handle when key changed)
	$logger->debug("Removig ".$ENV{'HOME'}."/.ssh");
	`rm -rf $ENV{'HOME'}/.ssh`;

	eval
	{
		#Connect
		$logger->debug("Connecting to server; $server with the following arguments: user-> $user, password-> $passChar"); 
		$sftp = Net::SFTP->new($server,%sftpArgs);
		$logger->debug("Creating new Net::SFTP::Attributes Object");
		$attrs = Net::SFTP::Attributes->new();
		$logger->debug("Setting Net::SFTP::Attributes object with permission of $filesPermission");
		$attrs->flags( $attrs->flags | SSH2_FILEXFER_ATTR_PERMISSIONS );
		$attrs->perm($filesPermission);
		$logger->debug("SFTP: using put command from $source to $target");
		$sftp->put($source, $target);
		$logger->debug("SFTP: using do_setstat command to change permission of $target to $filesPermission");
		$sftp->do_setstat($target,$attrs);
	};
	$err = $@;

	if ($err)
	{
		$logger->error("$err");
	}

	return(0);
}

sub getFile($$$$$)
{
	my ($server, $user, $pass, $source, $target) = @_;
	my %sftpArgs;
	my $sftp;
	my $passChar = "*" x length($pass);

	#Configure sftp user/password/port
	%sftpArgs = (user => $user,
		password  =>  $pass,
		ssh_args  =>  [port=>22]);

	#Cleanup SSH key (just in case that Net::SFTP doesn't how to handle when key changed)
	$logger->debug("Removig ".$ENV{'HOME'}."/.ssh");
	`rm -rf $ENV{'HOME'}/.ssh`;

	#Connect
	$logger->debug("Connecting to server; $server with the following arguments: user-> $user, password-> $passChar"); 
	$sftp = Net::SFTP->new($server,%sftpArgs);
	$logger->debug("SFTP: using get command from $source to $target");
	$sftp->get($source, $target);

	return(0);
}

########
# Main #
########
# Initialize logging behaviour
Log::Log4perl->init($LOGGER_CONF);

if (! $ARGV[3])
{
	$logger->error("Missing arguments");
	$logger->error("Usage: $0 <snmpmanager user> <snmpmanager password> <vi unit> <vi password>");
	exit(16);
}

if (! -e $IS4_PARAMETERS_FILE)
{
	$logger->error("$IS4_PARAMETERS_FILE Not exists");
	exit(11);
}

$sysDomain = readSysDomain();
$logger->info("System domain is: $sysDomain");

#Creating tmp dir
if (-d $TMP_WORD_DIR) 
{
	$logger->debug("$TMP_WORD_DIR found. Using \"rm -rf\" cmd to removing it");
	`rm -rf $TMP_WORD_DIR`;
	if ($?)
	{
		$logger->error("Failed to remove $TMP_WORD_DIR: $!");
		exit(13);
	}
}
$logger->info("Creating Temp Directory: $TMP_WORD_DIR");
`mkdir -p $TMP_WORD_DIR`;

#Initialize units hash variable (in order to retrieve the metdatafiles only from 1 unit for each type)
foreach (@SUPPORTED_UNITS)
{
	$logger->debug("Setting \$supportedUnits\{$_\} to false");
	$supportedUnits{$_}=0;
}

$logger->info("Getting scdb data from $SCDB_SERVER");
getFile($SCDB_SERVER, $SMU_USERNAME, $SMU_PASSWORD, $SCDB_REMOTE_FILE, $SCDB_NEW_FILE);

changeMode(0777, $SCDB_NEW_FILE);	#In order to avoid permission problem if script run AGAIN by other user then root

$logger->info("Sending sitebook script to $SCDB_SERVER");
sendFile($SCDB_SERVER, $SMU_USERNAME, $SMU_PASSWORD, $SITEBOOK_LOCAL_SCRIPT, $SITEBOOK_REMOTE_SCRIPT);

$logger->info("Getting list of units from scdb data");
@listOfUnits = parseScdb($SCDB_NEW_FILE);

foreach my $host (@listOfUnits)
{
	$logger->debug("Working on $host");
	if (! $supportedUnits{$supportedUnitTypes{$host}})
	{
		$logger->info("Getting metadafiles from $host");
		$metaDataLocalDirectory = $TMP_WORD_DIR."/".$supportedUnitTypes{$host};
		$logger->debug("First time to get metdada files from $supportedUnitTypes{$host} Unit Type");
		$logger->debug("Creating metaDataLocalDirectory directory");
		`mkdir -p $metaDataLocalDirectory`;
		if ($?)
		{
			$logger->error("Failed to create $metaDataLocalDirectory: $!");
			$warnings++;
			next();
		}

		if (getFiles($host, $SBUSER, $SBPASSWORD, $METADATA_REMOTE_DIRECTORY, $metaDataLocalDirectory))
		{
			$logger->error("Failed to get metadafiles from $host");
			$warnings++;
		}
		else
		{
			$logger->debug("Setting true in \$supportedUnits\{$supportedUnitTypes{$host}\} flag");
			$supportedUnits{$supportedUnitTypes{$host}}=1;
		}
	}
	else
	{
		$logger->debug("Already got metadata files from $supportedUnitTypes{$host} Unit Type");
	}
}

#sending metadata files to smu

foreach my $key (sort keys %supportedUnits)
{
	if ($supportedUnits{$key})
	{
		$logger->info("Sending metafiles of $key to SMU");
		sendFiles($SCDB_SERVER, $SMU_USERNAME, $SMU_PASSWORD, $TMP_WORD_DIR."/".$key, $METADATA_REMOTE_DIRECTORY);
		@listOfMetadaFiles=bsd_glob("$TMP_WORD_DIR/$key/*");

		$logger->info("Executing sitebook script on SMU");
		$logger->debug("Sending the following parameters to executeSiteBookScript: $SCDB_SERVER, $SMU_USERNAME, $SMU_PASSWORD, $sysDomain, @listOfMetadaFiles");
		($exitStatus,$output) = executeSiteBookScript($SCDB_SERVER, $SMU_USERNAME, $SMU_PASSWORD, $sysDomain, \@listOfMetadaFiles);
		if ($exitStatus)
		{
			$logger->error("Failed to execute sitebook script on $SCDB_SERVER");
			$logger->error("*** Starting output of sitebook script ***\n $output\n *** End output of sitebook script ***");
			$warnings++;
		}
		else
		{
			$logger->info("sitebook script executed successfully on $SCDB_SERVER");
			$logger->info("*** Starting output of sitebook script ***\n $output\n *** End output of sitebook script ***");
		}
	}
	else
	{
		$logger->error("Cant send metadafiles of $key since I failed to get it from all units");
		$warnings++;
	}
}


if (! $warnings)
{
	$logger->info("$0 script finished successfully");
}
else
{
	$logger->warn("$0 script finished successfully but failed on $warnings units");
	$logger->info("Log file can be found here: $INSTALLATION_AUDIT_LOG_FILE");
	exit(12);
}

$logger->info("Log file can be found here: $INSTALLATION_AUDIT_LOG_FILE");
exit(0);