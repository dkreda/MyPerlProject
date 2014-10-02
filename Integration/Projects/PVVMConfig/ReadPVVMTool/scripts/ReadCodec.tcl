#!/usr/bin/expect -f
###########################################
# Expect Test dcript

source ./common.tcl

proc getCodec {ParamName} {
set FileName "/usr/cti/conf/vxv/osa/util/AudioContentTypeMappings.properties"
expect "#"
set Result [WaitPrompt "\[^\/]Result:" "sed -n '/$ParamName/ s/^.*=/Result:/p' $FileName"]
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

proc InitParams {VxVVer} {
     switch -regexp -- $VxVVer \
     	 "4.2.*"  {  puts "--Info VxV Version is supported ..."
     		set Result($VxVVer,defaultContentTypeAudio) "/usr/cti/conf/vxv/osa/util/AudioContentTypeMappings.properties"
     		set Result($VxVVer,greetingAudio) "/usr/cti/conf/vxv/osa/util/AudioContentTypeMappings.properties"
     		set Result($VxVVer,bulletinAudio)   "/usr/cti/conf/vxv/osa/util/AudioContentTypeMappings.properties"
     	} default { puts "-- Warning Unsuported Compas version use default Locations"
     		set Result($VxVVer,defaultContentTypeAudio) "/usr/cti/conf/vxv/osa/util/AudioContentTypeMappings.properties"
     		set Result($VxVVer,greetingAudio) "/usr/cti/conf/vxv/osa/util/AudioContentTypeMappings.properties"
     		set Result($VxVVer,bulletinAudio)   "/usr/cti/conf/vxv/osa/util/AudioContentTypeMappings.properties"
     	}
     return [array get Result]
}



ReadParams
spawn ssh "admin@$CliParams(Host)"
if { "[AdminLogin]" != "O.K" } {
	error "Fail to Login to machine skip this script."
}
set OutPut(VxV_Ver) [getRpmVer vxv]

set CodecList "defaultContentTypeAudio greetingAudio bulletinAudio" 
set Default defaultContentTypeAudio

foreach Record $CodecList {
        set $Record [getCodec $Record]
        set DefList "default [set $Default]"
        set $Record [string map -nocase $DefList [set $Record]]
        puts "Default Value is [set $Default]"
        set OutPut($Record) [set $Record]
}

puts "\nFinish Script: \"[sshLogOut]\"\n"

WrAnswerFile $CliParams(AnswerFile) [array get OutPut]

