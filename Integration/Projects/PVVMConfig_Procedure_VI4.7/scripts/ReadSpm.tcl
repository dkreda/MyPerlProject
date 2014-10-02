#!/usr/bin/expect -f
###########################################
# Expect Test dcript

source ./common.tcl

proc ReadParameter {ParamName FileName} {
     ## puts "\n--Debug Wait Promt\n";
     expect timeout { return "Error - No Prompt" } "#"
     ## set Result [WaitPrompt "\[^\/]Result:\[\"']" "sed -n '/$ParamName/,/Item/ s/.*Item.*=/Result:/p' $FileName"]
     set Result [WaitPrompt "#" "/usr/cti/apps/CSPbase/Perl/bin/xpath $FileName '/Configuration/Parameters/Component/Group/Parameter\[\@Name=\"$ParamName\"\]/Value/Item/@Value'"]
     regexp Value=\[\'\"](\[^\"\']*)\[\'\"] $Result Full Result
     puts "-Debug  Result for $ParamName is $Result ( $Full )"
     expect *
     send "\r"
     expect .*
     return $Result
}

proc InitParams {CompasVer} {
     switch -regexp -- $CompasVer \
     	 "3.2.0.0.*"  {  puts "--Info Compas Version is supported ..."
     		set Result($CompasVer,TuiPasswordEncryptionMethod) "/usr/cti/conf/compas/common/parameters.xml"
     		set Result($CompasVer,MADefaultAddressDomain) "/usr/cti/conf/compas/common/parameters.xml"
     		set Result($CompasVer,MAPasswordEncyptionFormat)   "/usr/cti/conf/compas/common/parameters.xml"
     		set Result($CompasVer,InternetPasswordEncryptionMethod) "/usr/cti/conf/compas/common/parameters.xml"
     	} default { puts "-- Warning Unsuported Compas version use default Locations"
     		set Result($CompasVer,TuiPasswordEncryptionMethod) "/usr/cti/conf/compas/common/parameters.xml"
     		set Result($CompasVer,MADefaultAddressDomain) "/usr/cti/conf/compas/common/parameters.xml"
     		set Result($CompasVer,MAPasswordEncyptionFormat)   "/usr/cti/conf/compas/common/parameters.xml"
     		set Result($CompasVer,InternetPasswordEncryptionMethod) "/usr/cti/conf/compas/common/parameters.xml"
     	}
     return [array get Result]
}

proc getCompasVer {} {
expect "#"
return [getRpmVer ComPAS]
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
if { "[AdminLogin]" != "O.K" } {
	error "Fail to Login to machine skip this script."
}

set Answer(CompasVer) [getCompasVer]
array set ParamsArray [InitParams $Answer(CompasVer)]

set PasswordList {"TuiPassword:TuiPasswordEncryptionMethod" 
		  "ImapPassword:MAPasswordEncyptionFormat" 
		  "WebPassword:InternetPasswordEncryptionMethod" 
		  "MailDomain:MADefaultAddressDomain" }
		  
foreach Record $PasswordList {
	set LRecord [split $Record ":"]
	set Key [lindex $LRecord 0]
	set Val [lindex $LRecord 1]
	set Answer($Key) [ReadParameter $Val $ParamsArray($Answer(CompasVer),$Val)]
	puts "-Debug - Finish to read parameter $Key ...\n\n"
}

puts "\n\nFinish Script: \"[sshLogOut]\"\n"

WrAnswerFile $CliParams(AnswerFile) [array get Answer]
