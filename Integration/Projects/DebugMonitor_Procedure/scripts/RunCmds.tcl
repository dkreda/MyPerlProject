#!/usr/bin/expect -f
###########################################
# Expect Test dcript

source ./common.tcl

proc ReadParams {} {
     global CliParams
     set ParamList "Host Answer Cmdline"
     ParseCommandLine
     foreach Iter $ParamList {
     	if { ! [info exists CliParams($Iter) ] } {
     		error "missing parameter $Iter"
     	}
     }
}

ReadParams
spawn ssh "admin@$CliParams(Host)"
if { "[AdminLogin]" != "O.K" } {
	error "Fail to Login to machine skip this script."
}

expect *
send "\r"
expect "#"
expect *
WaitPrompt "#" $CliParams(Cmdline)

## WrAnswerFile $CliParams(Answer) [array get Results]