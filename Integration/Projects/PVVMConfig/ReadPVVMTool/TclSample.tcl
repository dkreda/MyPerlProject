#!/usr/bin/expect -f
###########################################
# Expect Test dcript

puts "Command Line Input:"
for { set i 0} {$i < [llength $argv]} {incr i} {
        puts "Argument $i [lindex $argv $i]"
}

set ParamList "Ip OutFile"
set Max [llength $ParamList]
if { $Max > [llength $argv] } {
	set Max [llength $argv]
}
for { set i 0} {$i < $Max} {incr i} {
        set [lindex $ParamList $i] [lindex $argv $i]
}

if { [info exists Ip] } {
puts "IP is $Ip"
}
if { [info exists OutFile] } {
puts "OutFile is $OutFile"
}