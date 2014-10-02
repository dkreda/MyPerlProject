%define Target %{ViewDir}/kits
%define SourceDir %{ViewDir}/Source
%define SwimBaseDir /var/cti/data/swim
%define SwimKits %{SwimBaseDir}/kits
%define SwimSys  %{SwimBaseDir}/systems

Summary:	Utility that creates system installation info for swim
Name:		%{_rpm_name}
Version:	%{_rpm_version}
Release:	%{_rpm_stf}
License:	Free
Vendor:		Comverse Inc
Group:		Applications/Swim
URL:		http://Google.com
Packager:	Anonymous
buildroot: %{_sourcedir}

%description
%{_rpm_name} Utility that help to create system info for swim installation
Revision:	%{_rpm_revision}

%prep
rm -rf %{_sourcedir}
mkdir -p %{_sourcedir}%{SwimKits}/CreateSystem/NDU-WHC
mkdir -p %{_sourcedir}%{SwimKits}/CreateSystem/MMG
mkdir -p %{_sourcedir}%{SwimKits}/CreateSystem/VI
mkdir -p %{_sourcedir}%{SwimSys}/SwimManger
mkdir -p %{Target}
cp %{SourceDir}/Linux/createSystem-CAF.xml 	%{_sourcedir}%{SwimKits}/CreateSystem/createSystem-CAF.xml
cp %{SourceDir}/Linux/BuildSwimSystem.pl 	%{_sourcedir}%{SwimKits}/CreateSystem/BuildSwimSystem.pl
cp %{SourceDir}/Common/Octopu2Twim.csv 		%{_sourcedir}%{SwimKits}/CreateSystem/Octopu2Twim.csv
cp %{SourceDir}/Common/NDU-WHC/NDU-UAF.xml 	%{_sourcedir}%{SwimKits}/CreateSystem/NDU-WHC/NDU-UAF.xml
cp %{SourceDir}/Common/NDU-WHC/AddWhcServic-SAF.xml %{_sourcedir}%{SwimKits}/CreateSystem/NDU-WHC/AddWhcServic-SAF.xml
cp %{SourceDir}/Common/NDU-WHC/DSU-UAF.xml 	%{_sourcedir}%{SwimKits}/CreateSystem/NDU-WHC/DSU-UAF.xml
cp %{SourceDir}/Common/NDU-WHC/OMU-UAF.xml 	%{_sourcedir}%{SwimKits}/CreateSystem/NDU-WHC/OMU-UAF.xml
cp %{SourceDir}/Common/NDU-WHC/SMU-UAF.xml 	%{_sourcedir}%{SwimKits}/CreateSystem/NDU-WHC/SMU-UAF.xml
cp %{SourceDir}/Linux/SwimManager_Linux-UAF.xml %{_sourcedir}%{SwimSys}/SwimManger/SwimManager_Linux-UAF.xml
cp %{SourceDir}/Common/UnitGroup.xml 		%{_sourcedir}%{SwimSys}/SwimManger/UnitGroup.xml
cp %{SourceDir}/Common/VI/CAS_Group-UAF.xml 	%{_sourcedir}%{SwimKits}/CreateSystem/VI/CAS_Group-UAF.xml
cp %{SourceDir}/Common/VI/GenVI-SAF.xml		%{_sourcedir}%{SwimKits}/CreateSystem/VI/GenVI-SAF.xml
cp %{SourceDir}/Common/VI/MTS_Group-UAF.xml	%{_sourcedir}%{SwimKits}/CreateSystem/VI/MTS_Group-UAF.xml
cp %{SourceDir}/Common/VI/PROXY_Group-UAF.xml	%{_sourcedir}%{SwimKits}/CreateSystem/VI/PROXY_Group-UAF.xml

%build

%pre

%files
%defattr(644,swim,swim)
%attr(755,swim,swim) %dir %{SwimKits}/CreateSystem/NDU-WHC
%attr(755,swim,swim) %dir %{SwimKits}/CreateSystem/MMG
%attr(755,swim,swim) %dir %{SwimKits}/CreateSystem/VI
%attr(755,swim,swim) %dir %{SwimSys}/SwimManger
%{SwimKits}/CreateSystem/Octopu2Twim.csv
%{SwimKits}/CreateSystem/NDU-WHC/NDU-UAF.xml
%{SwimKits}/CreateSystem/NDU-WHC/AddWhcServic-SAF.xml
%{SwimKits}/CreateSystem/NDU-WHC/DSU-UAF.xml
%{SwimKits}/CreateSystem/NDU-WHC/OMU-UAF.xml
%{SwimKits}/CreateSystem/NDU-WHC/SMU-UAF.xml
%{SwimKits}/CreateSystem/createSystem-CAF.xml
%{SwimKits}/CreateSystem/VI/CAS_Group-UAF.xml
%{SwimKits}/CreateSystem/VI/GenVI-SAF.xml
%{SwimKits}/CreateSystem/VI/MTS_Group-UAF.xml
%{SwimKits}/CreateSystem/VI/PROXY_Group-UAF.xml
%{SwimSys}/SwimManger/UnitGroup.xml
%{SwimSys}/SwimManger/SwimManager_Linux-UAF.xml
%attr(755,swim,swim) %{SwimKits}/CreateSystem/BuildSwimSystem.pl
%define _rpmdir %{Target}

%post
$HOSTNAME=`hostname`
$HOSTIP=nslookup $HOSTNAME | perl -n -e '/Address/i and /([\d\.]+)/ and print $1'
$UNITFILE=/var/cti/data/swim/systems/SwimManger/UnitGroup.xml
perl -pi -e -e 's/UnitName=".+?"/UnitName="$ARGV[1]"/;' -e 's/Ip=".+?"/Ip="$ARGV[0]"/' $UNITFILE $HOSTIP $HOSTNAME

%preun

%postun
