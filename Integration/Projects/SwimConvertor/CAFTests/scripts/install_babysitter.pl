#!/usr/bin/perl
							###################################
							#		Brajendra Nath Vimal      #
							###################################
use POSIX qw (uname);

sub isInstallationCompleted{
	my $tmpResponse=$_[0];
	if($tmpResponse != 0){
		print "\nError !!!, Installation of Babysitter is not completed!!!\n" ;
		      exit 1;
    }
}


sub isAlreadyInstalled{
    my $tmpResponse=$_[0];
    if($tmpResponse == 0){
      	print "\nWARNING !!!, Babysitter is already installed!!!\n" ;
      	exit 0;
    }
}


my ($os,undef, $os_version, $version, $arch) = POSIX::uname();

if (!($os =~ m/SunOS/i))
{
    `rpm -qa | grep -i babysitter >> /dev/null 2>&1`;
    $response=$?;
    isAlreadyInstalled($response);

   `cd /usr/tmp`;
   `rpm -ivh /usr/tmp/babysitter-ic-4.3.0.0-04.i386.rpm >> /dev/null 2>&1`;
	my $response=$?;

	isInstallationCompleted($response);

   `rpm -qa | grep -i babysitter >> /dev/null 2>&1`;
	$response=$?;
	isInstallationCompleted($response);
	print "\nInstallation of Babysitter rpm is completed!!!\n" ;
}
else
{
    `pkginfo | grep Babysitter >> /dev/null 2>&1`;
    $response=$?;
    isAlreadyInstalled($response);

   `cd /usr/tmp`;
   `pkgadd -a /usr/tmp/admin -d /usr/tmp/Babysitter_4.3.0.0_Build04 Babysitter >> /dev/null 2>&1`;
	my $response=$?;
	isInstallationCompleted($response);

	`pkginfo | grep -i babysitter >> /dev/null 2>&1`;
	 $response=$?;
	isInstallationCompleted($response);
	print "\nInstallation of Babysitter package is completed!!!\n" ;
}