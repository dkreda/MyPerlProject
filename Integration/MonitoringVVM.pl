[root@proxy-au1 /var/cti/logs/VVM-Monitor]# cat  /usr/cti/VVM-Monitor/vvm_monitor.pl
#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use IO::Socket::INET;
use Digest::MD5 qw(md5_hex);
use MIME::Base64;
use Getopt::Long qw( GetOptions );
my $report_dir  = "/var/cti/logs/VVM-Monitor";
my $bin_dir     = "/usr/cti/VVM-Monitor";

my $conf_file   = $bin_dir."/site.conf";
my $report_file = $report_dir."/VVM_test_summary_";
my $logfile     = $report_dir."/vvm_check.log";
my $old_logfile = $report_dir."/vvm_check_old.log";
my $auth_file   = $bin_dir."/auth.sh";

#my $smtp_template = $bin_dir."/smtp.txt";
my $timeout = 0;
my %units;
my %exclude_list;
my %test_users;
my $debug = 0;
my ($size);
my $buffer_size=500;
my $user_timeout = 0;
my $server_timeout = 0;
my $retry_timeout = 0;
my $alarm_unit = "snmpManager";

my $ERROR_STATUS = 1;
my $SUCCESS = 0;
my $max_reports = 1000;
my $max_file_time = 2*24*3600;
my $opt_alarm;
my $opt_single;
my $opt_unit_type;
my $opt_help;
my $VERSION = "1.0";
my $G_ErrorCounter=0;
sub ascii_to_hex 
{
        ## Convert each ASCII character to a two-digit hex number.
        (my $str = shift) =~ s/(.|\n)/sprintf("%02lx", ord $1)/eg;
        return $str;
}

sub getDit
{
        my $str=shift;
        my $what=shift;
#       print "$str\nlook for $what\n";
        my $index1=rindex ($str,"$what"."\"");
        my $num=length($what)+$index1;
#       print "$num\n";
        my $num2=$num+length("$what"."\"");
        my $index2=index ($str,"\"",$num2);
#       print "$num\n$index2\n";
        my $result= substr ($str,$num+1,$index2-$num-1);
#       print "$result\n";
}

main();
exit(0);

sub main {

        GetOptions(        
                'alarm'          => \$opt_alarm,
                'single'         => \$opt_single,
                'unit_type=s'    => \$opt_unit_type,
                'help'           => \$opt_help
        ) or die usage();

        if ($opt_help) {
                usage();
                return;
        }
        my $res    = 0;
        my $status = 0; 
                my $clear_file = "/tmp/clear.txt";
        read_config_file();

        # Check any old instance of the vvm_monitor process and kill it
        kill_old_instances();

        # Check if report directory exists, if not create it
        unless (-d "$report_dir") 
        {
                $res = `mkdir -p $report_dir 2>&1`;
                        print  STDERR "* Can't create log dir $report_dir\n" if $?;
                }

                # cleanup old reports
                clean_old_reports(); 

        # handle old log files
        if (-f $logfile) 
                {
                $size = (stat($logfile))[7];
                `mv $logfile $old_logfile 2>&1` if ( $size >= 8192000 );
                print STDERR "* Can't move old log file\n" if $?;
                }        
                logger("Starting vvm check");
        #clear all the alarms if not cleared already
        unless (-f "$clear_file") 
        {
                                send_alarm(5,"One/some of units not responding. Login to one/ some of users failed. Please refer to vvm_monitor log");
                                `touch $clear_file`;
                                }
        $status = check_vvm_status();

                if($G_ErrorCounter)
                                {
                                send_alarm($ERROR_STATUS, "One/some of units not responding. Login to one/ some of users failed. Please refer to vvm_monitor log");
                        `rm -f $clear_file`;
                                }

                #send_notify() if ($status != 0);
        #$status = check_jglue();
        #send_notify() if ($status != 0);
        logger("Finished vvm check");
}
#######################################################################
#
#       Function: read_config_file
#       Read Config file and initialize all the values
#
####################################################################### 
sub read_config_file {
        my $current_section = 0;

        open CONF_FILE, "<$conf_file" or die "site.conf file is not found. Exiting";
        while (<CONF_FILE>) {
                chomp;
                next if (!$_);

                if (($_ =~ m/^\[/) && ($_ =~ m/servers/i)){
                        $current_section = 1;
                        next;
                }
                if (($_ =~ m/^\[/) && ($_ =~ m/exclude/i)){
                        $current_section = 2;
                        next;
                }
                if (($_ =~ m/^\[/) && ($_ =~ m/Test Phone/i)){
                        $current_section = 3;
                        next;
                }
                                if (($_ =~ m/^\[/) && ($_ =~ m/general/i)){
                        $current_section = 4;
                        next;
                }

                next if ($_ =~ m/^#/);
                if ($current_section == 1) {
                        my($name, $temp_ip) = split(/=/);
                        $name = trim($name);
                        my ($ip, $trail) = split(",", $temp_ip);
                        print "$name is $ip \n" if ($debug);
                        if ((($opt_unit_type) && ($name =~ /^$opt_unit_type/i)) || (!$opt_unit_type)) {
                                if (!$units{$name}) {
                                $units{$name} = $ip;
                                }
                        }        
                }
                if ($current_section == 2) {
                        my @units_ar = split(/,/);
                        my $temp_unit;
                        foreach $temp_unit (@units_ar) {
                          $temp_unit = trim($temp_unit);
                          if (!$exclude_list{$temp_unit} && $units{$temp_unit}) {
                                $exclude_list{$temp_unit} = 1;
                          }
                          print "$temp_unit\n" if ($debug);
                        }
                }
                if ($current_section == 3) {
                        my($user_name, $pass) = split(/,/);
                        $user_name = trim($user_name);
                        $pass = trim($pass);
                        print "Test user: $user_name, $pass\n" if ($debug);
                        if (!$test_users{$user_name}) {
                                $test_users{$user_name} = $pass;
                        }
                }
                if ($current_section == 4) {
                        my($param_name, $param_value) = split(/=/);
                        $param_name = trim($param_name);
                        $param_value = trim($param_value);
                        $param_name = lc($param_name);
                        $user_timeout = $param_value if (($param_name eq "usertimeout") && ($param_value>0) && ($param_value < 60));
                        $server_timeout = $param_value if (($param_name eq "servertimeout") && ($param_value>0) && ($param_value < 60));
                        $retry_timeout = $param_value if (($param_name eq "retrytimeout") && ($param_value>0) && ($param_value < 120));
                        $alarm_unit     = $param_value if ($param_name eq "alarmtarget");
                }
        }
        print Dumper(\%units) if ($debug);
        print Dumper(\%exclude_list) if ($debug);
        print Dumper(\%test_users) if ($debug);

}
###########################################################################
#
#       Function: trim()
#       Trim the string of white spaces 
#
###########################################################################
sub trim($)
{
        my $string = shift;
        $string =~ s/^\s+//;
        $string =~ s/\s+$//;
        $string =~ s/^ *//;
        return $string;
}

###########################################################################
#
#       Function: run_imap_test()
#       Connects to the server provided in the argument with the given 
#       username and password. Executes the following commands: login, select
#               inbox, fetch headers, fetch body, delete, expunge, logout
#
###########################################################################

sub run_imap_test {

my ($MYServerName, $LoginName, $LoginPass) = @_;
my ($ser_res, $msg_num);
my ($port) = 50143;
my $format = 'S n a4 x8';

chomp($port);
 
my($tout_counter) = 0;
logger("In run_imap_test for $MYServerName with $LoginName / $LoginPass");

my $server = gethostbyname($MYServerName);

local $SIG{'ALRM'} = \&timed_out; # Set the timeout trigger
my $con_error = 1;
eval {
        alarm(15);
        return ($ERROR_STATUS, "ERROR connect: Server not defined\n") unless (defined($server));
        return ($ERROR_STATUS, "ERROR connect: Socket error\n") unless(socket(IMAP, AF_INET(), SOCK_STREAM(), 6));

        return ($ERROR_STATUS, "ERROR connect: Connect error\n") unless(connect(IMAP, pack($format, AF_INET(), $port, $server)));

        alarm(0);
        $con_error = 0;
};

if ($timeout == 1) {
        $timeout = 0;
        return ($ERROR_STATUS, "ERROR connect: TIMEOUT During execution");
}

if ($con_error != 0) {
        alarm(0);
        return ($ERROR_STATUS, "ERROR connect: Connect error - after alarm\n");
}
#return ($ERROR_STATUS, "ERROR connect: Connect error\n") unless ($con_error==0);
autoflush IMAP 1;
$ser_res = wait_response();

if ( $ser_res =~ /BYE disconnecting/i ) {return ($ERROR_STATUS, "ERROR: $ser_res\n"); } 
elsif ( $ser_res !~ /OK /i ) { return ($ERROR_STATUS, "ERROR: $ser_res\n"); } 
  
$ser_res = Command("1 capability");

return ($ERROR_STATUS, "ERROR capability: $ser_res\n")  unless ($ser_res =~ /\d\s+OK/ms);
################################eitan
#$ser_res = Command("1 login $LoginName $LoginPass");


#print "$LoginName $LoginPass\n";

$ser_res = Command("2 AUTHENTICATE digest-md5");
my @ser_res2 = split(' ',$ser_res);
#print "here is what i got:$ser_res2[1]\n";

#print "$auth_file $ser_res2[1] $LoginName $LoginPass\n";
#my $x=`$auth_file $ser_res2[1] $LoginName $LoginPass`;
my $x=`$auth_file $ser_res2[1] $LoginName $LoginPass`;
chomp($x);
#print "$x\n";
my $test=decode_base64($x);
print "$test\n";

$ser_res = Command($x);
#print "111 $ser_res\n";
$ser_res = Command1("");
#print "222 $ser_res\n";










############3
return ($ERROR_STATUS, "ERROR login: $ser_res\n")  unless ($ser_res =~ /\d\s+OK/);

$ser_res = Command("2 select inbox");   

return ($ERROR_STATUS, "ERROR select: $ser_res\n") unless ($ser_res =~ /\d\s+OK/ms);

$msg_num = $1 if ($ser_res =~ /(\d+)(\s+EXISTS)/m);
if ($msg_num > 0)
{
        $ser_res = Command("3 fetch 1:* (UID FLAGS ENVELOPE INTERNALDATE)");
        if (($ser_res =~ /\d\sNO/) || ($ser_res =~ /\d\sBAD/)) {
                return ($ERROR_STATUS, "ERROR fetch: $ser_res\n");
        }

        my $ser_res_fetch = Command("3 fetch $msg_num body[]");
        
   #     $ser_res = Command("4 store 1:* +flags \\deleted");
   #     return ($ERROR_STATUS, "ERROR delete: $ser_res\n") unless ($ser_res =~ /\d\s+OK/ms);

   #     $ser_res = Command("5 expunge");
   #     return ($ERROR_STATUS, "ERROR expunge: $ser_res\n") unless ($ser_res =~ /\d\s+OK/ms);

    return ($ERROR_STATUS, "ERROR fetch all: $ser_res\n") unless ($ser_res_fetch =~ /\d\s+OK/ms);
}

$ser_res = Command("l logout");
return ($ERROR_STATUS, "ERROR: $ser_res\n") unless ($ser_res =~ /^l\s+OK/m);

return ($SUCCESS, "Status: OK\n");

}
###########################################################################
#
#       Function: timed_out()
#       Handle the case of a timeout 
#
###########################################################################
sub timed_out
{
   $timeout = 1;
    return ($ERROR_STATUS, "ERROR connect: TIMEOUT During execution");

}
###########################################################################
#
#       Function: Command()
#       Send the command provided in the paramer to the server (IMAP4).
#               Wait for the response from the server for command execution and
#               return the result back to the caller 
#
###########################################################################
sub Command1
{
#       print "send Command1\n";
    my $ser_res = "";
    my $sendcommand = shift;
    my $EOT=$sendcommand;
    $EOT =~ s/\s.*$//;
    logger($sendcommand);
    send(IMAP, "$sendcommand\r\n", 0);
    $ser_res = wait_response ();

    $ser_res =~ s/\r+//g;
        return $ser_res;
}
sub Command
{
#       print "send Command\n";
    my $ser_res = "";
    my $sendcommand = shift;
    my $EOT=$sendcommand;
    $EOT =~ s/\s.*$//;
    logger($sendcommand);
    send(IMAP, "$sendcommand\r\n", 0);
    $ser_res = wait_response ();
    $ser_res =~ s/\r+//g;
    return ($ser_res) if ($ser_res =~ /^\+\s+/i);
    if ($ser_res !~ /^$EOT\s+/i) 
    {
        while(<IMAP>)
        { 
            $_ =~ s/^\s+//; 
            $_ =~ s/\r+//g;
            $ser_res .= $_;
            last if ($_ =~ /^$EOT\s+/i);
        }
    } 
        logger($ser_res);
        return $ser_res;
}
###########################################################################
#
#       Function: wait_response()
#       What for the valid input on the socket 
#
###########################################################################
sub wait_response
{
        my $res = "a";
    $res =<IMAP> while ($res eq "a");
    return $res;
}



###########################################################################
#
#       Function: check_vvm_status()
#       Check the status of the servers by executing SMTP deposit to test
#               mailbox and then IMAP4 retrieval from the test mailbox. The test
#               messages will be removed from the test mailbox upon successful IMAP
#               login session 
#
###########################################################################
sub check_vvm_status() {
        my $result = 0;
                my $cas_failure = 0;
                my $proxy_failure = 0; 
                my $cas_success = 0;
                my $proxy_success = 0;
        my $current_report = $report_file.get_current_date();

        if (-f $current_report) {
                open REPORT, ">>$current_report" or logger("Could not open report file $current_report");
        }
        else {
                open REPORT, ">$current_report" or logger("Could not open report file $current_report");
        }
                my $now = localtime;
        print REPORT "\n******************************************************\n";
        print REPORT "$now Test Execution Results:\n";
        print REPORT "\n******************************************************\n"; 
        foreach my $unit (sort keys %units) {

                print REPORT "$unit IP $units{$unit}: ";

                if ($exclude_list{$unit}) {
                        print REPORT "Unit excluded\n";
                        next;
                }
                                my %cas_user_result;
                                my $cas_user_fail = 0;
                foreach my $test_user (keys %test_users) {
 
              #  my ($err_status1, $out1) = run_smtp_test($units{$unit}, $test_user);
              #  if ($err_status1 != 0) {
              #  logger("Failed in smtp for $unit for user $test_user");
              #  logger($out1);
              #          }
        my ($err_status2, $out2) = run_imap_test($units{$unit}, $test_user, $test_users{$test_user}); 
        if ($err_status2 != 0) {
                #if login failed - retry 3 times with the interval of 1 minute
                logger("Failed to imap for $unit for user $test_user with password $test_users{$test_user}");
                logger($out2);
                                if ($opt_alarm) {
                if (($out2 =~ /ERROR connect/) || ($out2 =~ /ERROR login/)) {
                        logger("Retrying failed login or connect in $retry_timeout second(s)");
                        sleep($retry_timeout);
                        ($err_status2, $out2) = run_imap_test($units{$unit}, $test_user, $test_users{$test_user});
                        if ($err_status2 != 0) {
                                logger("Failed attempt 2: ");
                                logger($out2);
                                logger("Retrying failed login or connect in $retry_timeout second(s)");
                                sleep($retry_timeout);
                                ($err_status2, $out2) = run_imap_test($units{$unit}, $test_user, $test_users{$test_user});
                                if ($err_status2 != 0) {
                                        logger("Failed attempt 3: ");
                                        logger($out2);
                                        #send_alarm($ERROR_STATUS, "Unit $unit is not responding. Login to $test_user failed.");
                                                                                $G_ErrorCounter++;


                                }

                        }

                }
                                }
        }

                        #       if(($err_status2==0)){
                                #send_alarm(5, "Unit $unit is not responding. Login to $test_user failed.");
                        #       }
                        #       if (($err_status1==0) {
                               # $cas_user_result{$test_user} = "$test_user -Success\n";
                               # }
                                if (($err_status2!=0)) {
                                        
                                        my $temp_str = "$test_user - password=$test_users{$test_user} FAILED. Details:";
                                    #    $temp_str = $temp_str."$out1" if ($err_status1!=0);
                                        $temp_str = $temp_str."$out2" if ($err_status2!=0);
                                                                                $cas_user_result{$test_user} = $temp_str;
                                        $cas_user_fail++;

                                }
                                # perform only 1 user session if single option was specified

                                last if ($opt_single);
                                sleep($user_timeout) if ($user_timeout>0);

                } 
                if ($cas_user_fail == 0) {
                                    print REPORT "Success\n";
                                        $cas_success++ if ($unit =~ m/cas/i);
                        $proxy_success++ if ($unit =~ m/prox/i);
                }
                                else {
                                        print REPORT "\n";
                                        $cas_failure++ if ($unit =~ m/cas/i);
                                        $proxy_failure++ if ($unit =~ m/prox/i);
                                        foreach my $usr_result (sort keys %cas_user_result) {
                                                 print REPORT "\t $cas_user_result{$usr_result}";
                                        }
                                }
                sleep($server_timeout) if ($server_timeout>0);
        }

    print REPORT "\nSummary\n";
    print REPORT "CAS: Success $cas_success \nFailure $cas_failure\n\n";
    print REPORT "Proxy: Success $proxy_success \nFailure $proxy_failure\n\n";  
    close(REPORT);    
    return;

}

###########################################################################
#
#       Function: run_smtp_test()
#       Perform SMTP message deposit to the specified account  
#
###########################################################################
=comment
sub run_smtp_test() {

my ($MYServerName, $mailTo) = @_;


my($inpBuf) = '';
my($mailFrom)   = $mailTo;
my($realName)   = "VVM_test";
my($subject)    = 'Test';
my($body)       = "Test Line One.\nTest Line Two.\n";
my($ser_res)      = 0;

my($port)    = 50025;
my($tout_counter) = 0;
my $sock;

local $SIG{'ALRM'} = \&timed_out;

logger("In run_smtp_test() for $MYServerName with $mailTo");
 
eval 
{
    alarm(15);
    $sock = IO::Socket::INET->new(PeerAddr => $MYServerName,
                                 PeerPort => $port,
                                 Proto    => 'tcp');
        # if connection can not be established - return with an error
        return ($ERROR_STATUS, "ERROR connect: Socket error\n") unless ($sock);
        alarm(0);
};

if ($timeout == 1) {
        $timeout = 0;
        return ($ERROR_STATUS, "ERROR connect: TIMEOUT During execution");
}
#return ($ERROR_STATUS, "ERROR connect: Socket error\n") unless ($sock);
if (!defined($sock)) {
        alarm(0);
        return ($ERROR_STATUS, "ERROR connect: Socket error - aftre failure\n");
}

$sock->autoflush(1);
$sock->recv($ser_res, $buffer_size);
# If server busy - close socket and quit !!!
return($ERROR_STATUS, "SMTP - server busy, this is OK\n") if ( $ser_res =~ /^421 / );  
return($ERROR_STATUS, "SMTP out of service\n") unless ( $ser_res =~  /^220.*ready/i );

# Start sending commands to smtp server 
$sock->send("EHLO d\n");
$sock->recv($ser_res, $buffer_size);
return($ERROR_STATUS, "ERROR: $ser_res\n") unless ($ser_res =~ /250.* /);
logger("$ser_res\n");

$sock->send("MAIL From: <$mailFrom>\n");
$sock->recv($ser_res, $buffer_size);
$ser_res=trim($ser_res);
logger("$ser_res\n");
return($ERROR_STATUS, "ERROR: $ser_res\n") unless ($ser_res =~ /^250.*OK$/m);
$sock->send("RCPT To: <$mailTo>\n");
$sock->recv($ser_res, $buffer_size);
$ser_res=trim($ser_res);
logger("$ser_res\n");
return($ERROR_STATUS, "ERROR: $ser_res\n") unless ($ser_res =~ /^250.*OK$/m);
$sock->send("DATA\n");
$sock->recv($ser_res, $buffer_size);
$ser_res=trim($ser_res);
logger("$ser_res\n");
return($ERROR_STATUS, "ERROR: $ser_res\n") unless ($ser_res =~ /^354 Start mail input/);

# if mail template exists - send the smtp message with the data in the template
# otherwise send just a default test message
#if (open SMTP_DATA, "<$smtp_template") {
#        $body = "";
#        while (<SMTP_DATA>) {
#                $body = $body.$_;
#        }
#        close(SMTP_DATA); 
#}
#else { 
#        $sock->send("From: $realName\n");
#        $sock->send("Subject: $subject\n", 0);
#}
$sock->send($body);
$sock->send("\r\n.\r\n");
$sock->recv($ser_res, $buffer_size);
logger("$ser_res\n");
   
return($ERROR_STATUS, "ERROR: $ser_res\n") unless ($ser_res =~ /^250.*Mail accepted/);
$sock->send("QUIT\n");
$sock->recv($ser_res, $buffer_size);
$ser_res=trim($ser_res);
logger("$ser_res\n");
return($ERROR_STATUS,"ERROR: $ser_res\n") unless ($ser_res =~ /^221.*QUIT/);
return ($SUCCESS, "Status: OK\n");
}
=cut
#####################################################################
#
#        Function: logger() 
#        Print the information into the logger file
#
#####################################################################
sub logger  {

        my $now = localtime ;
        local $, = "" ;
        local $\ = "\n" ;
        open LOG, ">>$logfile" or return ;
        print LOG $now, ": ", @_ ;
        close LOG ;
        return undef ;

}
###########################################################################
#
#       Function: clean_old_reports()
#       Checks the number of report files in report directory. Delete 
#               old report files  
#
###########################################################################

sub clean_old_reports {
        my $num_of_reports=`ls -l $report_dir/VVM_test_summary_* 2>/dev/null | grep -v total | wc -l`;
        chomp $num_of_reports;

        # this is needed just as a precaution not to have too many report files
        while ($num_of_reports > $max_reports) {
        my $current_file=`ls -tr $report_dir/VVM_test_summary* | head -1`;
        chomp $current_file;

        `rm -f $current_file`;
        if ($? != 0) {
                logger("In clean_old_reports: Cannot delete $current_file - $?");
                }
                else {

                logger("$current_file file deleted");
                }
        $num_of_reports=`ls -l $report_dir/VVM_test_summary_* | grep -v total | wc -l`;
        }

        # delete any report that is more than 7 days old
        opendir(DIR, $report_dir) || die "can't opendir $report_dir $!";                foreach (readdir DIR) {
                next if ((m/^\./) || (m/^\.\./)); 
                next unless (m/VVM_test_summary/);
                my $file_name = $report_dir."/".$_;
                my $creation_time = (stat($file_name))[10];
                my $current_time = time; 
                if (($current_time - $creation_time) > $max_file_time) {
                        `rm -f $file_name`;
                        if ($? != 0) {
                                logger("In clean_old_reports: Cannot delete $file_name - $?");
                        }
                        else {

                        logger("$file_name file deleted");
                        }
                }
        }
        closedir(DIR);
}


#############################################################################
# Function: kill_old_instances()
# 
# Check for any old vvm_monitor process and kill it
#############################################################################
sub kill_old_instances {
   my $pid = $$;
   my %ps ;   
   open PS, 'ps -e -o pid -o comm| grep vvm | grep -v \$pid|' or die "Can't get process list\n" ;   
   while (<PS>) {      
        $ps{$1} = $2 if /(\d+)\s+([^\s]+)/ ;   
   }
   foreach my $old_pid (keys %ps) {
        next if ($old_pid == $pid);
        `kill -9 $old_pid`;
        if ($? != 0) {
            logger("Could not kill $old_pid");
        }
        else {
            logger("Successfully killed old instance of $ps{$old_pid} with PID $old_pid");
        }
   }   
   return;
}
#############################################################################
# Function: get_current_date()
# 
# Return current date (for report name generation) 
#############################################################################

sub get_current_date {
    my ($wkday,$month,$day,$time,$year) = split(/\s+/, localtime);
    return "$day-$month-$year-$time";

}
#############################################################################
# Function: usage()
# 
# Print the usage message 
#############################################################################

sub usage {
print "vvm_monitor.pl - Perform the audit of the VVM scenarios\n";
print "Version: $VERSION\n\n";
print "Usage: .//vvm_monitor.pl [-alarm] [-single] [--unit_type=cas|proxy] [-help]\n\n";
print "This program performs SMTP deposit and IMAP4 retrieval for the set of
test mailboxes specified in the configuration file (site.conf). \nThe options are:
-alarm
With this option specified the VVM certification tool shall generate alarms 
on the following events:
        Can not connect to CAS (issue alarm after 3 tries)
        Login failed (issue alarm after 3 failures)

-single
With this option the VVM certification script will run the set of tests only
for a single account (first configured) 

-unit_type
With this option specified the monitoring script will only run for the units 
whose name matches the values provided in the argument specification.

-help
This help.\n";}

#############################################################################
# Function: send_alarm()
# 
# Send SNMP trap to SMU 
#############################################################################

sub send_alarm {

my ($alrm_severity, $alrm_txt) = @_;
my ($wkday,$month,$day,$time,$year) = split(/\s+/, localtime);
my ($sec,$min,$hour,$mday,$mon) = localtime();
return if (!$opt_alarm);
$mon +=1;
my $hostname = `hostname`;
$hostname = trim($hostname);
my $alarm_string = "";
if($alrm_severity == 5){
$alarm_string = "snmptrap -v 2c -c GAS361LI $alarm_unit \"\" 1.3.6.1.4.1.5271.2.1.1.4 \\";
}
else
{
$alarm_string = "snmptrap -v 2c -c GAS361LI $alarm_unit \"\" 1.3.6.1.4.1.5271.2.1.1.2 \\";
}
$alarm_string.= "1.3.6.1.4.1.5271.2.2.2.3.1.0 s \"WebLogicJGlue\" \\";
$alarm_string.= "1.3.6.1.4.1.5271.2.2.2.3.2.0 s \"$hostname\" \\";
$alarm_string.= "1.3.6.1.4.1.5271.2.2.2.3.3.0 i 10 \\";
$alarm_string.= "1.3.6.1.4.1.5271.2.2.2.3.4.0 s \"$mday/$mon/$year $time\" \\";
$alarm_string.= "1.3.6.1.4.1.5271.2.2.2.3.5.0 i 1000002 \\";
$alarm_string.= "1.3.6.1.4.1.5271.2.2.2.3.6.0 i 34 \\";
$alarm_string.= "1.3.6.1.4.1.5271.2.2.2.3.7.0 i \"$alrm_severity\" \\";
$alarm_string.= "1.3.6.1.4.1.5271.2.2.2.3.8.0 i 1 \\";
$alarm_string.= "1.3.6.1.4.1.5271.2.2.2.3.9.0 i 0 \\";
$alarm_string.= "1.3.6.1.4.1.5271.2.2.2.3.10.0 i 1 \\";
$alarm_string.= "1.3.6.1.4.1.5271.2.2.2.3.11.0 s \"\" \\";
$alarm_string.= "1.3.6.1.4.1.5271.2.2.2.3.12.0 s \"unit is not responding\" \\";
$alarm_string.= "1.3.6.1.4.1.5271.2.2.2.3.13.0 s \"$alrm_txt\" \\";
$alarm_string.= "1.3.6.1.4.1.5271.2.2.2.3.14.0 o 1.3.6.1.4.1.5271.2.2.1.2.2 ";

#print $alarm_string;
my $res = system($alarm_string);
#my $res = 0;
logger("alarm sent - $res");

}

