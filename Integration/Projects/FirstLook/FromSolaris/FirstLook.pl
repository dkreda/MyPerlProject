#!/usr/local/bin/perl
use strict;
use POSIX;
my $UNIT="SMU";
my $OS="Solaris";
my $FLDIR = "/opt/CMVT/ICC/FirstLook";
my $optnum;
my $unitidx;
my $unitacc;
my %units;
my @ufile;
my $opt;
my $UNIT_STR;
my $UNIT_ACC;
my $deff;
my $file;
my $desc;
my @cfiles;
my $DEF_FILE;
my $DEF_STR;
my $j;

sub printhelp {
    my $unit;
    my $symptom;

    open (pgout,"| less");
    print pgout "\nThe following table should help you find out which unit and function to select, ";
    print pgout "based on the kind of problem you are handling.\n";
    print pgout "Just look up a symptom, most resembling that of the problem.\n\n";

    open (ldef,"grep  '^ *func' def/collect*.def | sort -k2 |");

    print pgout "| Unit (first menu)  | Function (second menu)                        ";
    print pgout "| Symptom(s)                                    |\n";
    while ($deff = <ldef>) {
          chop $deff;
          ($file,$unit,$desc) = split(/:/,$deff);
          $desc =~ s/^\s+//;
          $unit =~ s/^\s*func\s*//;

          print pgout "+--------------------+-----------------------------------------------";
          print pgout "+-----------------------------------------------+\n";
          printf pgout ("| %-18s | %-45s |",$unit,$desc);

          open(sdef,"grep symptom $file |");

          $symptom = <sdef>; 
          chop $symptom;
          $symptom =~ s/\s*symptom\s*//;
          printf pgout (" * %-43s |\n",$symptom);

          while ($symptom = <sdef>) {
                chop $symptom;
                $symptom =~ s/\s*symptom\s*//;
                printf pgout ("|                    |                                               | * %-43s |\n",$symptom);
                }
          }
    print pgout "+--------------------+-----------------------------------------------";
    print pgout "+-----------------------------------------------+\n";
    close (pgout);
    print "\n\n";
    }

chdir $FLDIR;

do {
   $optnum = 0;
   %units = "";
   system("clear");
   print "\n\nFirstLook version 0.1b\n\n";
   print "Please select Unit type or area \n";
   open (ldef,"grep -h '^ *func' def/collect*.def | sort -k2 |");

   while ($unitidx = <ldef>) {
         chop $unitidx;
         $unitidx =~ s/\s*func\s+(\S+)\s+:\s+(\S+)\s.*$/\1/;
         $unitacc = $2;
         next if ($units{$unitidx});
   
         $units{$unitidx} = 1;
         $ufile[$optnum] = "$unitidx $unitacc";
         print $optnum+1 . "\t$unitidx\n";
         $optnum = $optnum+1;
         }

   close (ldef);
   print "\nh\tHelp\n";
   print "x\tExit\n";
   print "? ";
   $opt = <STDIN>;
   chomp $opt;

   &printhelp if ($opt eq "h");

   die "Bye Bye!\n" if ( $opt eq "x");
   } while ( ($opt < 1) || ( $opt eq "h" ) || ! ($opt =~ /^\d+$/) || ! (($UNIT_STR,$UNIT_ACC) = split(/ /,$ufile[$opt-1])));

do {
   print "Please select function of $UNIT_STR\n";
   open ldef,"grep '^ *func  *$UNIT_STR *:*:' def/collect*.def| sort -k4 |";
   $optnum = 0;
   while ($deff = <ldef>) {
     ($file,$j,$j,$desc) = split(/:/,$deff);
     $desc =~ s/^\s+//;
     $cfiles[$optnum] = $file;
     print $optnum+1 . "\t$desc";
     ++$optnum;
     }

   print "\nx\tExit\n";
   print "? ";
   $opt = <STDIN>;
   chomp $opt;

   die "Bye Bye!\n" if ( $opt eq "x");

   }until (($opt > 0) && ($opt =~ /^\d+$/ ) && ($DEF_FILE = $cfiles[$opt-1]));

print "\nOutput of this First Look run will include:\n";
system ("grep -s  '^ *info' def/collect.$UNIT_ACC.main.def | sed 's/^ *info//'");
system ("grep -s '^ *info' def/collect.$UNIT_STR.common.def | sed 's/^ *info//'");
system ("grep -s '^ *info' $DEF_FILE | sed 's/^ *info//' 2>/dev/null");

$DEF_STR = $DEF_FILE;
$DEF_STR =~ s/^def.collect.//;
$DEF_STR =~ s/.def$//;


exec "bin/collect.pl $DEF_STR $UNIT_STR $UNIT_ACC";
