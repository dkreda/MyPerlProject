#!/usr/local/bin/perl
use strict;
use POSIX;
use lib ("/usr/local/lib/perl5/site_perl/5.8.3","/usr/local/lib/perl5/5.8.3","/usr/local/lib/perl5/5.8.3/sun4-solaris");
use Net::SSH::Perl;
use Net::SSH::Perl::Constants qw( :msg );

my %options = (
        use_pty => 0,
        protocol => 2
        );

my $host = $ARGV[0];
my $cmd = join(" ",@ARGV[1..$#ARGV]);
print "--Debug - Ruuning at sshme !!\n";
my $userpass = <STDIN>;
chop $userpass;
my ($user,$pass) = split(/:/,$userpass);

my @inlines = <STDIN>;
my $stdin = join("\n",@inlines);

my $ssh = Net::SSH::Perl->new($host,%options);

print "-Debug sshme create new object about to login ....\n";
$ssh->login($user,$pass);

print "--Debug Login succesfully .....\n";

$ssh->register_handler("stdout", sub {
    my($channel, $buffer) = @_;
    my $outme = $buffer->bytes;

    my $endme = ($outme =~ s/\n?(\d+) end-sshme$//);
    my $xstat = $1;

    print STDOUT $outme;

    if ($endme) {
       print STDERR "\n";
       exit $xstat;
       }
    });

$ssh->register_handler("stderr", sub {
    my($channel, $buffer) = @_;
    print STDERR  $buffer->bytes;
    });

my ($output,$error,$exit) = $ssh->cmd($cmd . ';echo $? end-sshme',$stdin);
exit $exit;
