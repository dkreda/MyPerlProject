#!/usr/bin/expect -f
###########################################
# Expect Test dcript

source ./common.tcl

proc ReadParams {} {
     global CliParams argv
     set ParamList [list Source Dest User Password]
     set Inputvars [concat $argv ftm maSis001]
     set IndxCounter 0
     foreach Iter $ParamList {
        set Param $Iter 
        set CliParams($Param) [lindex $Inputvars $IndxCounter]
        incr IndxCounter
     }
     if  { ! [info exists CliParams(User) ]} {
               set CliParams(User) ftm
     }
     if  { ! [info exists CliParams(Password) ]} {
               set CliParams(Password) maSis001
     }
}

ReadParams
#puts "Debug - Commad line:"
#foreach Stam [array names CliParams] {
#	puts "$Stam ==> $CliParams($Stam)"
#}
spawn scp "$CliParams(User)@$CliParams(Source)" "$CliParams(Dest)"

if { "[PassLogin $CliParams(Password)]" != "O.K" } {
	error "Fail to Login to machine skip this script."
}
expect #
##expect *
## WrAnswerFile $CliParams(Answer) [array get Results]