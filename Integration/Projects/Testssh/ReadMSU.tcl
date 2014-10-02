#!/usr/bin/expect -f
###########################################
# Expect Test dcript

source ./common.tcl

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

proc getHostList {HostName} {
     expect {
        timeout { error "Fail to Read Host $HostName from Trm hosts file." }
        "#"
     }
     set FileName "/etc/hosts"
     set Count 0
     send  "grep -i $HostName $FileName\r"
     expect {
           timeout { error "Internal Error - Try to remove send command ..." }
           "ts\r"
     }
     while { $Count >= 0 } {
        expect {
                timeout { error "Error - grep Timeout..." }
                "]#" { set Count "-1" 
                       send "\r" }
                -reg "(\[^\r]*)\r" {
                        ##set Result($Count) $expect_out(1,string)
                        regexp (\[^\r\n]*)$ $expect_out(1,string) Full Result($Count)
                        incr Count
                }
        }
     }
     if { [info exists Result] } { return [array get Result] }
}

proc ReadMSU {} {
     set CompList "Mips"
     foreach Iter $CompList {
        set List [getHostList $Iter]
        ## set Name [join "$Iter IP" "_"]
        regexp (\[0-9]+\.\[0-9]+\.\[0-9]+\.\[0-9]+) $List Full Result($Iter)
     }
     if { [info exists Result] } { return [array get Result]}
}

ReadParams
spawn ssh "root@$CliParams(Host)"
if { "[PassLogin Adm1Cmv4\$]" != "O.K" } {
        error "Fail to Login to machine skip this script."
}

array set InfoArray [ReadMSU]
sshLogOut

WrAnswerFile $CliParams(AnswerFile) [array get InfoArray]
puts "MSU Result:"
foreach Iter [array names InfoArray] {
    puts "-- $Iter => $InfoArray($Iter)"
}
