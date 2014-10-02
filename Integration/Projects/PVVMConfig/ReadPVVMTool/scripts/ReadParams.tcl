#!/usr/bin/expect -f
###########################################
# Expect Test dcript

source ./common.tcl

proc ParseParams {File List} {
	puts "Not Ready yet\n"
}

proc ReadConfig {File} {
	set fd [open $File r]
	set file_data [read $fd]
	set Func(xml) "XmlRead"
	set Func(ini) "IniRead"
	set Func(txt) "TxtRead"
	set Func(cmd) "CmdRead"
	close $fd
	puts "-- Finish to read $File\n"
	foreach Line [split $file_data "\n"] {
	      if [regexp ^(\[^\#\]+?)=(.+?):(.+)//(.+)$ $Line Junk Result Type FilePath Param] {
	      	puts "-- Display: $Result"
	      	puts " + File:    $FilePath"
	      	puts " + Type:    $Type"
	      	puts " + Parameter:$Param\n\n\n"
	      	set ParamArray($Result) [$Func($Type) $FilePath $Param]
	      	puts "Parse Result: $ParamArray($Result)"
	      } elseif [regexp \# $Line Junk ] {
	      	puts "-- Remark Line Ignore ...\'$Line\'\n"
	      } elseif [regexp ^$ $Line ] {
	      	puts "-- Empty Line Ugnore"
	      } else {
	      	error "Input File Format Error - can not Read Line \'$Line\'"
	      }
	}
	return [array get ParamArray]
}

proc CmdRead {Cmd Pattern} {
	return [WaitPrompt "$Pattern" "$Cmd"]
}


proc XmlRead {File Xpath} {
	puts "-- XmlRead Not Ready. Input: $File , $Xpath\n"
	set Result [WaitPrompt "NODE --..." "/usr/cti/apps/CSPbase/Perl/bin/xpath $File '$Xpath'"]
	if [regexp "/@\[^/]+$" $Xpath Junck ] {
		regexp =(.+)$ $Result Junk Result
	} else {
		regexp >(.+)< $Result Junk Result
	}
	expect #
	return $Result
}

proc IniRead {File Param} {
	puts "-- IniRead Not Ready. Input: $File , $Param\n"
	if [regexp \\\[(.+?)\](.+)$ $Param Junk Key PName] {
	   set Result [WaitPrompt "\\nResult:" "perl -wn -e '/$Key/.../^\\\[.*\\]/ and s/^$PName=// and print \"Result:\$_\"' $File"]
	} else {
	   set Result [TxtRead $File $Param]
	}
	return $Result
}

proc TxtRead {File Param} {
	puts "-- TxtRead Not Ready. Input: $File , $Param\n"
	expect *
	set Result [WaitPrompt "\\nResult:" "perl -wn -e 's/^$Param=// and print \"Result:\$_\"' $File"]
	puts "-- Results is \"$Result\" ..." 
	return $Result
}

proc ReadParams {} {
     global CliParams
     set ParamList "File Host Answer"
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
array set Results [ReadConfig $CliParams(File)]
puts "\n\nFinish Script: \"[sshLogOut]\"\n"
puts "List of Parameters:"
foreach Iter [array names Results] {
	puts "- $Iter = $Results($Iter)"
}

WrAnswerFile $CliParams(Answer) [array get Results]