#!/bin/sh
cp -p /usr/cti/conf/tcm/tcm-conf.xml /usr/cti/conf/tcm/tcm-conf.temp
sed '/<applications>/ a\
		<application name="VAN">\
			<tcm-server-url>http://TCMServer:51446/tcm/tcmbill</tcm-server-url>\
			<delayed-credit-time>0</delayed-credit-time>\
			<delayed-credit-supported>yes</delayed-credit-supported>\
			<aoc-required>no</aoc-required>\
			<charging-parameters-filter>example-filter</charging-parameters-filter>\
			<configuration-set-id>gcdr-configuration-set</configuration-set-id>\
		</application>' < /usr/cti/conf/tcm/tcm-conf.temp > /usr/cti/conf/tcm/tcm-conf.xml
rm /usr/cti/conf/tcm/tcm-conf.temp
