#!/usr/bin/expect -f
###########################################
# Expect Test dcript

source ./common.tcl

proc getBalanceMode {} {
expect "#"
return [ReadParam "/usr/cti/conf/balancer/balancer.conf" "EnableReceivedRequestAuth"]
}

proc getIP {host} {
expect "#"
set IPNum [WaitPrompt "\[^/]Result:" "nslookup $host | grep -A 1 $host | sed -n '/Address/ s/\[^0-9\]*/Result:/p'"]
regexp (\[0-9]+\.\[0-9]+\.\[0-9]+\.\[0-9]+) $IPNum Full Result
if { ! [info exists Result] } {set Result "Error: Unknown IP" }
return $Result
}

proc getNetDomain {} {
expect "#"
set Result [WaitPrompt "\[^\"]Result:" "awk '/domain/ {print \"Result:\"\$2}' /etc/resolv.conf"]
return $Result
}

proc ReadParams {} {
     global CliParams
     set ParamList "Host AnswerFile"
     ParseCommandLine
     foreach Iter $ParamList {
     	if { ! [info exists CliParams($Iter) ] } {
     		error "missing parameter $Iter"
     	}
     }
}

ReadParams
spawn ssh "admin@$CliParams(Host)"
set Iter 20
while { $Iter < 150 } {
    set Message [AdminLogin]
    if { "$Message" == "O.K" } {
    	set Iter 500
    }
    set Iter [expr $Iter * 2]
    set timeout $Iter
    puts $Message
}
if { "$Message" != "O.K" } {
	error "Fail to Login to machine skip this script.\n$Message"
}
set HostList "MIPS SPM VxV"
foreach Host $HostList {
	set [join "$Host IP" "_"] [getIP $Host]
}
set Balancer_Sync_Mode [getBalanceMode]
set NetDomain [getNetDomain]
puts "\n\nFinish Script: \"[sshLogOut]\"\n"
set OutFile [open  $CliParams(AnswerFile) "w"]
puts $OutFile "Sync_Mode=$Balancer_Sync_Mode"
puts $OutFile "NetDomain=$NetDomain"
foreach Host $HostList {
	puts $OutFile "[join "$Host IP" "_"]=[set [join "$Host IP" "_"]]"
}
