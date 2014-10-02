#!/usr/bin/expect -f
###########################################
# Expect Test dcript

source ./common.tcl

proc StartSql {} {
set timeout 5
send "\r"
expect "#"
## puts "Debug StartSql: - >>\"$expect_out(buffer)\"<<"
send "su - oracle\r"
expect "\\\$"
send "sqlplus \"/as sysdba\"\r"
expect ">"
set Temp "O.K"
## puts "Debug - After Insert to sqlplus application Temp is $Temp"
return $Temp
}


proc RunSql {Query} {
send "\r"
expect ">"
set Result [WaitPrompt "SQL>" "$Query"]
return $Result
}

proc StopSql {} {
set timeout 10
send "\r"
expect *
set Temp [WaitPrompt "\\\$" "Quit"]
set Temp [WaitPrompt "#" "exit"]
puts "\nDebug - Return to root shell - Result is $Temp ...\n\n"
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
while { $Iter < 50 } {
    set Message [AdminLogin]
    if { "$Message" == "O.K" } {
    	set Iter 500
    }
    set Iter [expr $Iter * 2]
    set timeout $Iter
    puts "Info: Login to $CliParams(Host) Status: $Message"
}
if { "$Message" != "O.K" } {
	error "Fail to Login to machine skip this script.\n$Message"
}

StartSql
set Line [RunSql "SET LINESIZE 300;"]
set Groups [RunSql "SELECT GSL_GROUP_ID,GSL_GROUP_NAME,COSHOSTNAME FROM GSL_OWNER.GSL_GROUPS;"]
StopSql

puts "\n\nFinish Script: \"[sshLogOut]\"\n"
set OutFile [open  $CliParams(AnswerFile) "w"]
puts $OutFile "$Groups"


