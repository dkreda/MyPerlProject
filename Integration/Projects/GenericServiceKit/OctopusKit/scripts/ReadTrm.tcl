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

proc ReadTrm {} {
     set CompList "MSU TRM INFORMIX"
     foreach Iter $CompList {
        set List [getHostList $Iter]
        for {set Inx 0} { $Inx < [llength $List] } { incr Inx 2} {
        	## puts "-- Debug List Index $Inx is [lindex $List $Inx] -> [lindex $List [expr $Inx + 1]]"
                set Result([lindex $List $Inx],$Iter) [lindex $List [expr $Inx + 1]]
        }
     }
     if { [info exists Result] } { return [array get Result]}
}

proc getTrmID {TrmList} {
     array set Result "TRM_IP Unknown TRM_ID Unknown"
     array set TrmArray $TrmList  
     foreach Indx [array names TrmArray] {
     	if [string match -nocase "*vip" $TrmArray($Indx)] {
     	    puts "-- Debug Parse Trm Line: \"$TrmArray($Indx)\""
     	    regexp ^(\[0-9\.]*).*trm(\[0-9]*)(\[^0-9]|\$) $TrmArray($Indx) Full Result(TRM_IP) Result(TRM_ID) Ignore
     	}
     }
     return [array get Result]
}

proc getMSUList {MSUList} {
     array set MsuArray $MSUList
     foreach Indx [array names MsuArray] {
     	regexp -nocase ^(\[0-9\.]*).*msu(\[0-9]*) $MsuArray($Indx) Full MSU_IP MSU_ID
     	set Result(MSU$MSU_ID) $MSU_IP
     }
     return [array get Result]
}

proc getTrmList {} {}


ReadParams
spawn ssh "root@$CliParams(Host)"
if { "[PassLogin Adm1Cmv4\$]" != "O.K" } {
        error "Fail to Login to machine skip this script."
}

array set InfoArray [ReadTrm]
sshLogOut
puts "Trm Result:"
foreach Iter [array names InfoArray] {
    puts "-- $Iter => $InfoArray($Iter)"
}

regexp ^(\[0-9\.]*) $InfoArray(0,MSU) Full MsuIP
array set TrmInfo [getTrmID [array get InfoArray *TRM]]

#set Answer(MsuIP) $MsuIP
set Answer(TRM_ID) $TrmInfo(TRM_ID)
set Answer(TRM_IP) $TrmInfo(TRM_IP)

array set MsuInfo [getMSUList [array get InfoArray *MSU]]
foreach Iter [array names MsuInfo] {
	set Answer($Iter) $MsuInfo($Iter)
	## puts "$Iter=$MsuInfo($Iter)"
}
regexp ^(\[0-9\.]*) $InfoArray(0,INFORMIX) Full Inf_IP 
set Answer(INFORMIX_IP) $Inf_IP
## puts "INFORMIX_IP=$Inf_IP"
switch -- $CliParams(AnswerFile) \
     " " {set OutFile Null
     } "-*" {set OutFile Null
     } default {set OutFile [open  $CliParams(AnswerFile) "w"]}
      
foreach Iter [array names Answer] {
	if { "$OutFile" == "Null" } {
	   puts "$Iter=$Answer($Iter)"
	} else {
	   puts $OutFile "$Iter=$Answer($Iter)"
	}
}