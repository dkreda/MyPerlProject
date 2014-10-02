#!/usr/cti/apps/CSPbase/Perl/bin/perl
## #!/usr/local/bin/perl
use strict;
use POSIX;

my $FLDIR = "/usr/cti/Integration";
my $RUNS_ON = "OMU";
my $FILESFIX;
my $OUTFILE;
my $ARCHFILE;
my $TEMPFIX;
my $TEMPFILE;
my $LOCKFIX;
my $LOCKFILE;
my %args;
my %xdict;
my %fails;
my %passwords;
my %hostsubs;
my $outfiles;
my $archfiles;
my $run_func;
my $run_common;
my $run_acc;
my $endstatus;
my $attention = 1;

my %actions = (
  func => 1,
  common => 1,

  errorlevel => 1,
  symptom => 1,

  usingssh => sub {
      unless ($run_common eq $RUNS_ON) {
             print "\n**\n**\n**\n";
             print "\nYou are going to use ssh to access remote hosts.\n";
             print "Please enter the default $args{usingssh} password: ";
             system "stty -echo";
             $passwords{"default:$args{usingssh}"} = <STDIN>;
             chomp $passwords{"default:$args{usingssh}"};
             system "stty echo";
             print "\n";
             }
      },

  info => sub {
    &writeout("-+-+-+ $args{info} +-+-+-");
  },

  define => sub {
     my $var;
     my $val;
     my %xdv;

     $val = $args{define};
     $val =~ s/\s*(\w+)\s//;
     $var = $1;

     $xdv{$var} = $val;
     $xdict{$var} = \%xdv;
     },

  setenv => 1,

  tell => sub {
     if ($attention) {
        print "\n**\n**\n**\n";
        $attention = 0;
        }
     print "\r" . $args{tell} . "\n";
     },

  reset => sub {
     my $resarg;

     $resarg = $args{reset};
     system ("cat /dev/null > $TEMPFILE") if (($resarg eq "outfix") && ($args{outfix} eq "TEMP"));
     $args{$resarg} = "";
     },

  outfix => sub {
    my $outfile;
    my $outfix = $args{outfix};

    unless ($outfix eq "TEMP") {
           $args{outfix} = ""; # To trick writeout to write to the main log
           $outfile = $OUTFILE;
           $outfile =~ s/_MAIN.txt$/_${outfix}.txt/;
           &writeout("Additional output is in $outfile");
           $args{outfix} = $outfix;
           }
    },

  host => 1,

  files => sub {
    my $cmd = "tar cvf - ";
    &doexec("cd $args{files};$cmd","ARCHIVE");
    },

  cmds => sub {
     my $cmd = "/bin/sh";
     &doexec("$cmd","CMDS");
     },

  script => sub {
    my $cmd = $args{script};
    &doexec($cmd,"SCRIPT");
    },

  prompt => sub {
     my $ans;
     my $ptext;
     my $var;
     my %xdv;

     $ptext = $args{prompt};
     $ptext =~ s/\s*(\w+)\s//;
     $var = $1;
     print "\n$ptext ";
     $ans = <STDIN>;
     chop $ans;
     $xdv{$var} = $ans;
     $xdict{$var} = \%xdv;
     &writeout("$ptext $ans");
     $attention = 1;
     },

  fails => sub { $fails{$args{extract}} = $args{fails}; },

  extract => 1,
  xlabel => 1,
  xvalue => sub {
    my $exitem = $args{extract};
    my $label = $args{xlabel};
    my $value = $args{xvalue};
    my $cr;
    my $ml;
    my $mv;
    my $xdr;
    my %xdv;
    my $outfile;

    $outfile = $OUTFILE;

    if ($args{outfix}) {
       if ($args{outfix} eq "TEMP") {
          $outfile = $TEMPFILE;
          }
       else {
          $outfile =~ s/_MAIN.txt$/_$args{outfix}.txt/; 
          }
       }

    open (cf,$outfile);

    while ($cr = <cf>) {
      chomp $cr;

      if ($cr =~ /$label/) {
         if ($1) { $ml = $1; } else { $ml = $&; }
         }

      if ($cr =~ /$value/) {
         if ($1) { $mv = $1; } else { $mv = $&; }

         $xdr = $xdict{$exitem};

         %xdv = %$xdr if ($xdr);
         $xdv{$ml} = $mv;
         $xdict{$exitem} = \%xdv;
         }
     }
     close(cf);
  }
);

sub doexec {
   my $mode = pop;
   my $rcmd = pop;
   my $xcmd;
   my $ipid;
   my $fc;
   my $archfix;
   my @lc;
   my @mh;
   my $mhn;
   my $fh;
   my $cidx;
   my $outfile;
   my $scriptcmd;
   my $exit;
   my $hostname;

   $fh = 1;

   @mh = split(/\s+/,$args{host});
   $mhn = pop(@mh);

   do {
      $mhn =~ s/\s//g;


      if ($mhn eq "LOCAL") {
         $hostname = `hostname`;
         chop $hostname;
         }
      else {
            if (($hostname = &loginpass($mhn)) eq "") {
               $endstatus = $args{errorlevel} if ($endstatus < $args{errorlevel});
               &wrapup if ($endstatus == 3); 
               }
            }
      $cidx = 0;
      $scriptcmd = "";
     
      while (((($fh && ($xcmd = &getnext) ne "end")) || ($xcmd = $lc[$cidx]))) {
            next if ($xcmd =~ /^\s*$/);

            if ($fh) {
               $lc[$cidx] = $xcmd;
               }
            $cidx = $cidx + 1;

            $xcmd =  $args{setenv} . ";"  . $xcmd if (($args{setenv}) && ($mode eq "CMDS") && ($mhn ne "LOCAL"));
            
            if ($mode eq "CMDS") {
               &writeout("|$xcmd","",$mhn);
               }
            elsif ($mode eq "SCRIPT") {
                  $scriptcmd = $scriptcmd . $xcmd . "\n";
                  }
            else {
                 $scriptcmd = $scriptcmd . $xcmd . " ";
                 }
            }

         if ($mode ne "CMDS") {
            if ($mode eq  "ARCHIVE") {
               $archfix = $args{files};
               $archfix =~ s/\//_/g;
               $archfix = $archfix . "_" . $hostname;

               &writeout("See list of archived file below");
               &writeout("|$rcmd $scriptcmd| gzip > ${ARCHFILE}_$archfix.tar.gz","",$mhn);
               }
            else {
                 $rcmd = $args{setenv} . ";" . $rcmd if ($args{setenv});
                 &writeout("|$rcmd",$scriptcmd,$mhn);
                 }
            }
         $fh = 0;
       } while ($mhn = pop(@mh));
   }

sub loginpass {
    my $host = $_[0];
    my $newhost;
    my $newpass;
    my $errout;
    my $outout;
    my $ok = 0;
    my $hostname;

    pipe stdor,stdow;
    pipe stder,stdew;
    select stdew;$|=1;
    select stdow;$|=1;
    select STERR;$|=1;
    select STDOUT;$|=1;

    do {
       open (STDERR,">&stdew");
       open (STDOUT,">&stdow");

       while ($hostsubs{$host} ne "") { $host = $hostsubs{$host} ; };

       ## system ("ping -v $host 30 2>&1");
       system ("ping -c 2 $host 2>&1 | grep \"packet loss\"");
       $outout = <stdor>;

       if ($outout =~ / 0% packet loss/) {
          open (lp,"|$FLDIR/bin/sshme.pl $host 'hostname;iostat -c | grep \" [0-9][0-9.]* \"'");
          print lp "$args{usingssh}" . ":" . $passwords{"default:$args{usingssh}"} . "\n";
          close lp;
          $errout = <stder>;
          open (STDOUT,">/dev/tty"); 
          open (STDERR,">/dev/tty"); 

          if (($errout =~ /Permission denied/) || ($errout =~ /authentication failures/)) {
             print "\n**\n**\n**\n";
             print "\nPermission denied in login to $host\n";
             print "Please re-enter password or press <enter> to skip $host\n";
             print "\nPlease re-enter $args{usingssh} password: ";
             system "stty -echo";
             $newpass = <STDIN>;
             system "stty echo";
             print "\n";
             chop $newpass;
             return("") unless ($newpass);
             $passwords{"default:$args{usingssh}"} = $newpass;
             chomp $passwords{"default:$args{usingssh}"};
             print "\nRetrying connection...\n";
             }
         elsif ($errout =~ /Bad host name/) {
               print "Wrong hostname was given or $host cannot be accessed for some other reason.\n";
               &writeout("Wrong hostname was given or $host cannot be accessed for some other reason.\n");
               return("")
               }
         else { 
              $hostname = <stdor>;
              chop $hostname;
              $outout = <stdor>;
              chop $outout;
              $outout =~ s/^.*\s+(\S+)\s*$/\1/;
              if ($outout < 31) {
                 $endstatus = $args{errorlevel} if ($endstatus < $args{errorlevel});
                 print "\rCPU idle on $hostname is only $outout% . FL commands on this host will be skipped.\n";
                 &writeout("CPU idle on $hostname is only $outout% . FL commands on this host will be skipped.");
                 return("");
                 }
              $ok = 1; 
              }
         }
       else   {
              open (STDOUT,">/dev/tty"); 
              open (STDERR,">/dev/tty"); 
              print "No ping to $host\n";
              
              if ($hostsubs{$host} eq "") {
                 print "\n**\n**\n**\n";
                 print "This is the first attempt to access $host.\n";                   
                 print "If you think the problem is that the host name is wrong, please enter new hostname below.\n";
                 print "Otherwise, just press enter.\n";
                 print "\nEnter host IP or name as it is known from the SMU: ";
                 $newhost = <STDIN>;
                 chomp $newhost;
                 return("") if ($newhost eq "");

                 print "Retrying connection...\n";
                 $hostsubs{$host} = $newhost;
                 $host = $newhost;
                 }
              else {
                   &writeout("Host $host cannot be accessed for some reason.\n");
                   return("");
                   }
              }
       } while (! $ok);

    return($hostname);
    }

sub writeout {
    my $outtxt = $_[0];
    my $input = $_[1];
    my $host = $_[2];
    my $output;
    my $outfile = $OUTFILE;
    my $outexpr = "";
    my $arch;
    my $exec = 0;
    my $status;

    if ($args{outfix}) {
       if ($args{outfix} eq "TEMP") {
          $outfile = $TEMPFILE;
          }
       else {
          $outfile =~ s/_MAIN.txt$/_$args{outfix}.txt/;
          }
       }

    ($outtxt,$arch) = split(/>/,$outtxt);

    if ($outtxt =~ /^\|/) {
       $exec = 1;
       while ($hostsubs{$host} ne "") { $host = $hostsubs{$host} ; };
       if ($host ne "LOCAL") { 
          $outexpr = "| $FLDIR/bin/sshme.pl $host ";
          $outtxt =~ s/\|//;
          $outtxt = "\'" . $outtxt . "\'";
          $output = "$args{usingssh}" . ":" . $passwords{"default:$args{usingssh}"} . "\n";
          }
       $outexpr = $outexpr . $outtxt;
   
       if ($arch) { 
          $outexpr = $outexpr . " > " . $arch;
          system("echo output of last command is in $arch >> $OUTFILE");
          }
       else {
            $outexpr = $outexpr . " >> " . $outfile;
            }
       $output = $output . $input;
       }
    else { 
          $outexpr = ">>$outfile"; 
          $output = $outtxt;
          };

    open(STDERR,">>$OUTFILE");
   
    open (wo,"$outexpr"); 
    print wo "$output\n" if ($output);
    close(wo);
    $status = $? & 255 ;

    open (STDERR,">/dev/tty");

    if (($exec) && ($status != 0)) {
        $endstatus = $args{errorlevel} if ($endstatus < $args{errorlevel});
        if ($endstatus == 3) {  # If we have a severe problem, there is no point to continue
           print "\nAborting collection because this command failed:\n";
           print $outtxt. "\n";
           &wrapup;
           }
        }
    }

sub getnext {
     my $olin = "";
     my $ret = "";
     my $dictitem;
     my $xdv;
     my $dictv;
     my $lin;
     my $keyw;
     my $sub;

     print ".";
     $olin = <cfg>;
     next if ($olin =~ /^\s*$/);
     chomp $olin;
     $olin =~ s/^\s+//;
     $olin =~ s/\s+$//;

     while ($olin =~ /\{(\S+)\}/) {
        $dictitem = $1;

        if ($dictitem =~ /(\w+):(.+)/) {
           $xdv = $xdict{$1};
           $dictv = $$xdv{$2};
           }
        else {
          $xdv = $xdict{$dictitem};
          $dictv = join(" ",values(%$xdv));
          }

        if ($dictv eq "" ) {
           print "\n**\n**\n**\n";
           print "\n$dictitem cannot be extracted. $fails{$dictitem}.\n See $OUTFILE for more details.\n";
           $endstatus = 3;
           &wrapup;
           }
        $olin =~ s/\{(\S+)\}/$dictv/;
        }

     $lin = $olin;
     $lin =~ s/\w+\s*//;
     $keyw = $&;
     $keyw =~ s/(\w+)\s*/\1/;

     $args{$keyw} = $lin;

     if ($actions{$keyw}) {
        if (ref($actions{$keyw}) eq "CODE") {
           $sub = $actions{$keyw};
           &$sub;
           }
        }
     elsif ($keyw ne "end") {
        return $olin; # Anything which is not a special command is returned as it is
        }
     else {
        return "end";
        }
     return(" ");
   }

sub wrapup {
    $args{outfix} = "ENDSTATUS";

    print "\n**\n**\n**\n";

    if ($endstatus == 1) {
       print "\nNOTE: Some of the commands executed for collecting info failed.\n";
       print "However, this could be indicative of the researched problem so please send the output as requested.\n";
       print "A notice about this will be added to $OUTFILE.\n";
       &writeout("****NOTE Some of the commands executed failed. Could be indicative of researched problem");
       }
    elsif ($endstatus == 2) {
          print "\nNOTE: Some of the commands executed for collecting info failed.\n";
          print "This may indicate a serious problem in the system.\n";
          print "Please contact Comverse support for assistance.\n";
          &writeout("****NOTE Some of the commands executed failed. May indicate a serious problem in the system");
          }
    elsif ($endstatus == 3) {
          print "\nNOTE: Collection process did not complete.\n";
          print "This may indicate a serious problem in the system.\n";
          print "Please contact Comverse support for assistance.\n";
          &writeout("****NOTE Collection process did not complete. May indicate a serious problem in the system");
          }
    else {
         print "\nDone.\n";
         &writeout("FirstLook collection completed successfully.");
         }

    chdir("$FLDIR/output");
    $archfiles = `ls $FILESFIX*`;
    $archfiles =~ s/\n/ /g;
    print "\nThe following files will be archived to $outfiles.tar.gz:\n";
    system("tar cvf -   $archfiles | gzip > $FILESFIX.tar.gz");
    system("rm -f $archfiles $TEMPFIX");
    system("rm $LOCKFIX");

    exit $endstatus;
    }

sub precheck {
    my $diskspace;
    my $lockid;
    my $runfl;

    $diskspace = `df -k $FLDIR | grep -v Filesystem | awk \'{print \$4}\'`;
    chop $diskspace;

    if ($diskspace < 15000) {
       print "Not enough free disk space in $FLDIR for FirstLook to run. Aborting.\n";
       $endstatus = 3;
       &wrapup;
       }

    $lockid = `cat $LOCKFILE 2>/dev/null`;
    chop $lockid;

    if ($lockid) {
       $runfl = `ps -ef | grep $lockid | grep -v grep`;
       chop $runfl;

       if ($runfl) {
          print "Another FirstLook collection for the same scenario is already running. Aborting this one.\n";
          exit -1;
          }
       }
    system ("echo $$ > $LOCKFILE");
    }
    
$run_func = $ARGV[0]; 
$run_common = $ARGV[1];
$run_acc = $ARGV[2] || die "usage: collect.pl func area acc\n";

my @da=localtime(time);
my $ds = "";

foreach (@da[4]+1,@da[3,5,2,1]) {
   my $me = $_;
   $me =~ s/^(\d)$/0\1/;
   $me =~ s/^1(\d\d)$/\1/;
   $ds = $ds . $me;
   }

$FILESFIX = "FirstLook.$run_func.$ds";
$TEMPFIX = "Temp.$run_func.$ds";
$TEMPFILE = "output/$TEMPFIX";
$LOCKFIX = "Lock.$run_func";
$LOCKFILE = "output/$LOCKFIX";
$outfiles = "output/$FILESFIX";
$OUTFILE = $outfiles . "_MAIN.txt";
$ARCHFILE = "$FLDIR/$outfiles";

&precheck;


print "List of output files created will be printed when the script finishes\n";
print "\nCollection may take up to 10-15 minutes, depends on the system and the info collected\n";

`echo Starting information collection > $OUTFILE`;
`date >> $OUTFILE`;

open (cfg,"cat -s def/collect.$run_acc.main.def def/collect.$run_common.common.def def/collect.$run_func.def |");

while (!eof(cfg)) {
   print ".";
   &getnext;
   }

close (cfg);
&wrapup;
