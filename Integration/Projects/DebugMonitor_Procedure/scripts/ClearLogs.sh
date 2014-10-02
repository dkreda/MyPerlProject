#!/bin/sh
/usr/cti/ServiceKit/LogMonitor.pl -Conf /usr/cti/conf/ServiceKit/LogMonitor.cfg -LogFile - /tmp/Remote_LogMaonitor.log -Remote -ClearLogs $*
