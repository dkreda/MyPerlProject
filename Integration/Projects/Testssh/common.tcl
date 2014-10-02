#!/usr/bin/expect -f
###########################################
# Expect Test dcript

proc PassLogin {Password} {
     set ErrMessage "O.K"
     ## puts "-- Procedure PassLogin Input $Password\n"
     expect {
        timeout {set ErrMessage "TimeOut - Password Prompt take too long"}
        "Permission denied" {set ErrMessage "Invalid ssh Key"}
        eof {set ErrMessage "Error - remote host close connection !" }
        "word:"
     }
     if { $ErrMessage == "O.K" } {
        send "$Password\r"
     }
     return $ErrMessage
}

proc AdminLogin {} {
     foreach pass "aDm4cu2t Adm1Cmv4$" {
        set ErrMessage [PassLogin $pass]
        if { $ErrMessage == "O.K" } {
            expect {
                timeout { return "Fail to get shell prompt" }
                "\\\$" { puts "\nInfo: Loggin as Admin succesfully"
                         send "su -\r"
                       }
                ">" { puts "\nInfo: Loggin as Admin succesfully"
                         send "su -\r"
                       }
                "#"    { puts "\nInfo: Loggin as root succesfully" 
                	 send "\r" }
            }
        } else { break }
     }
     ## put $expect_out(1,string)
     return $ErrMessage
}

proc sshLogOut {} {
     set ErrMessage "Loop"
     send \r
     while { $ErrMessage == "Loop" } {
     	expect {
     	     eof {set ErrMessage "LogOut succesfully"}
     	     timeout {set ErrMessage "Fail to Logout due to timeout"}
     	     -reg "\[>#\\\$]" {send "exit\r"}
     	}
     }
     return $ErrMessage
}

proc ParseCommandLine {} {
     global CliParams argv
     foreach Iter $argv {
        ## puts "-- Debug Parsing $Iter"
        set Val [string trimleft $Iter "-"]
        if { "$Val" == "$Iter" } {
            if  { ! [info exists Param ]} {
               error "Unknown parameter $Iter"
            }
            set CliParams($Param) $Iter
            ## puts "== Debug set CliParm $Iter , $CliParams($Param)"
            unset Param
        } else { set Param $Val }
     }
}

proc WaitPrompt {Prompt command} {
     puts "-- debug in Wait prompt"
     set timeout 3
     set WaitState "Waiting"
     set Result $WaitState
     ## set Val "\\r(.+?)\\r"
     ##set Val "(.+?)\\\[\\r\\n]"
     set Val "\[\r\n](.*)\[\r\n]"
     expect *
     puts "-- Debug WaitPrompt (Commomn) Result Before running command $Result"
     send "$command\r"
     while { $Result == $WaitState } {
        expect {
              timeout { puts "-- Time Out WaitPromt !!!"
              		expect *
        	        set Result "Error - TimeOut command \"$command\""
        	        puts "Error - TimeOut command \"$command\"\nInput: \"$expect_out(buffer)\"\nExpect:\"$Prompt\""
     	      } eof { puts "-- Command closed ..."
     	      	      set Result "Error - ubnormal Termination"
     	      } -reg "$Val.*?$Prompt" { set Result  $expect_out(1,string)
     	      		puts "-- Read Value: \"$expect_out(1,string)\"\nBuffer:$expect_out(buffer)"
     	      }
     	}
     }
     ##puts "Debug - >>>>>>   Finish Read .... WaitPromt $Prompt ...\n"
     ## puts "DDDDDDEBUG   -  Check the new line character\nDDDDDDDD - Second Line"
     return $Result
}

proc ReadParam {FileName ParamName} {
     set Result [WaitPrompt "\[^/]Result:" "sed -n '/$ParamName/ s/^.*=/Result:/p' $FileName"]
     return $Result
}

proc getRpmVer {RpmName} {
     set CmdList "rpm -qi `rpm -qa | grep -i $RpmName` | sed -n '/\\(Version\\|Release\\)/ s/^\\(\[^:]*:\[^:]\[^: \\t]*\\).*\$/\\1/p'"
     set Result "Loop"
     send "$CmdList\r"
     while { $Result == "Loop" } {
     	expect {
     	     timeout { set Result "Error: TimeOut" }
     	     "rpmq:" { set Result "Error: Rpm Not exists" }  
     	     -reg "Version\[ \t]*:(\[^\r]*)" { set Ver $expect_out(1,string) }
     	     -reg "Release\[ \t]*:(\[^\r]*)" { set Result [join "$Ver $expect_out(1,string)" "-"] }
     	}
     }
     puts "-- Common Debug rpm Result is $Result"
     expect .*#
     return $Result
}

proc WrAnswerFile {FileName ParamList} {
     array set Parray $ParamList
     switch -- $FileName \
     " " {set FileName Null
     } "-*" {set FileName Null
     } default {set FileName [open $FileName "w"]}
      
     foreach Iter [array names Parray] {
	if { "$FileName" == "Null" } {
	   puts "$Iter=$Parray($Iter)"
	} else {
	   puts $FileName "$Iter=$Parray($Iter)"
	}
     }
}

     	      ### } -reg "$Val\[^\r]*?$Prompt" { puts "-- Read Value: \"$expect_out(1,string)\""
