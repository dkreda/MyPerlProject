%define Target %{ViewDir}/kits
%define SourceDir %{ViewDir}/Build
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
AutoReqProv: no

%description
%{_rpm_name} Utility that help to create system info for swim installation
Revision:	%{_rpm_revision}

%prep
rm -rf %{_sourcedir}
mkdir -p %{_sourcedir}%{SwimKits}/CreateSystem/NDU-WHC
mkdir -p %{_sourcedir}%{SwimKits}/CreateSystem/MMG
mkdir -p %{_sourcedir}%{SwimKits}/CreateSystem/VI
mkdir -p %{_sourcedir}%{SwimKits}/CreateSystem/Demo
mkdir -p %{_sourcedir}%{SwimKits}/AddServiceUtil/NDU-WHC
mkdir -p %{_sourcedir}%{SwimKits}/AddServiceUtil/MMG
mkdir -p %{_sourcedir}%{SwimKits}/AddServiceUtil/VI
mkdir -p %{_sourcedir}%{SwimKits}/AddServiceUtil/scripts
mkdir -p %{_sourcedir}%{SwimSys}/SwimManger
mkdir -p %{Target}
cp %{SourceDir}/Common/createSystem-CAF.xml 	%{_sourcedir}%{SwimKits}/CreateSystem/createSystem-CAF.xml
cp %{SourceDir}/Common/BuildSwimSystem.pl 	%{_sourcedir}%{SwimKits}/CreateSystem/BuildSwimSystem.pl
cp %{SourceDir}/Common/BuildCvl.pl 		%{_sourcedir}%{SwimKits}/CreateSystem/BuildCvl.pl
cp %{SourceDir}/Common/MMG_UnitMap.csv 		%{_sourcedir}%{SwimKits}/CreateSystem/MMG_UnitMap.csv
cp %{SourceDir}/Common/NDU-WHC_UnitMap.csv	%{_sourcedir}%{SwimKits}/CreateSystem/NDU-WHC_UnitMap.csv
cp %{SourceDir}/Common/Demo_UnitMap.csv		%{_sourcedir}%{SwimKits}/CreateSystem/Demo_UnitMap.csv
cp %{SourceDir}/Common/VI_UnitMap.csv 		%{_sourcedir}%{SwimKits}/CreateSystem/VI_UnitMap.csv
cp %{SourceDir}/Common/NDU-WHC/NDU-UAF.xml 	%{_sourcedir}%{SwimKits}/CreateSystem/NDU-WHC/NDU-UAF.xml
cp %{SourceDir}/Common/SwimManager-UAF.xml 	%{_sourcedir}%{SwimSys}/SwimManger/SwimManager_Linux-UAF.xml
cp %{SourceDir}/Common/UnitGroup.xml 		%{_sourcedir}%{SwimSys}/SwimManger/UnitGroup.xml
cp %{SourceDir}/Common/VI/CAS_Group-UAF.xml 	%{_sourcedir}%{SwimKits}/CreateSystem/VI/CAS_Group-UAF.xml
cp %{SourceDir}/Common/VI/GenVI-SAF.xml		%{_sourcedir}%{SwimKits}/CreateSystem/VI/GenVI-SAF.xml
cp %{SourceDir}/Common/VI/MTS_Group-UAF.xml	%{_sourcedir}%{SwimKits}/CreateSystem/VI/MTS_Group-UAF.xml
cp %{SourceDir}/Common/VI/PROXY_Group-UAF.xml	%{_sourcedir}%{SwimKits}/CreateSystem/VI/PROXY_Group-UAF.xml


cp %{SourceDir}/Common/MMG/MMG_AddOns-SAF.xml	%{_sourcedir}%{SwimKits}/CreateSystem/MMG/MMG_AddOns-SAF.xml
cp %{SourceDir}/Common/MMG/MMSGW-UAF.xml	%{_sourcedir}%{SwimKits}/CreateSystem/MMG/MMSGW-UAF.xml
cp %{SourceDir}/Common/MMG/NDU_WHC-UAF.xml	%{_sourcedir}%{SwimKits}/CreateSystem/MMG/NDU_WHC-UAF.xml
cp %{SourceDir}/Common/MMG/PROXY-UAF.xml	%{_sourcedir}%{SwimKits}/CreateSystem/MMG/PROXY-UAF.xml
cp %{SourceDir}/Common/MMG/MTS_Group-UAF.xml	%{_sourcedir}%{SwimKits}/CreateSystem/MMG/MTS_Group-UAF.xml




cp %{SourceDir}/AddService/createSystem-CAF.xml	%{_sourcedir}%{SwimKits}/AddServiceUtil/createSystem-CAF.xml
cp %{SourceDir}/AddService/scripts/CreatSys.pl	%{_sourcedir}%{SwimKits}/AddServiceUtil/scripts/CreatSys.pl
cp %{SourceDir}/AddService/scripts/CreatAddServiceSys.pl %{_sourcedir}%{SwimKits}/AddServiceUtil/scripts/CreatAddServiceSys.pl
cp %{SourceDir}/AddService/NDU-WHC/DSU_Group-UAF.xml %{_sourcedir}%{SwimKits}/AddServiceUtil/NDU-WHC/DSU_Group-UAF.xml
cp %{SourceDir}/AddService/NDU-WHC/LVU_Group-UAF.xml %{_sourcedir}%{SwimKits}/AddServiceUtil/NDU-WHC/LVU_Group-UAF.xml
cp %{SourceDir}/AddService/NDU-WHC/OMU_Group-UAF.xml %{_sourcedir}%{SwimKits}/AddServiceUtil/NDU-WHC/OMU_Group-UAF.xml
cp %{SourceDir}/AddService/NDU-WHC/SMU_Group-UAF.xml %{_sourcedir}%{SwimKits}/AddServiceUtil/NDU-WHC/SMU_Group-UAF.xml
cp %{SourceDir}/AddService/NDU-WHC/VM_ASU_Group-UAF.xml %{_sourcedir}%{SwimKits}/AddServiceUtil/NDU-WHC/VM_ASU_Group-UAF.xml
cp %{SourceDir}/AddService/NDU-WHC/NDU-WHC-SAF.xml %{_sourcedir}%{SwimKits}/AddServiceUtil/NDU-WHC/NDU-WHC-SAF.xml
cp %{SourceDir}/AddService/MMG/DSU_Group-UAF.xml %{_sourcedir}%{SwimKits}/AddServiceUtil/MMG/DSU_Group-UAF.xml
cp %{SourceDir}/AddService/MMG/IS3_CMD_Unit-UAF.xml %{_sourcedir}%{SwimKits}/AddServiceUtil/MMG/IS3_CMD_Unit-UAF.xml
cp %{SourceDir}/AddService/MMG/LVU_Unit-UAF.xml %{_sourcedir}%{SwimKits}/AddServiceUtil/MMG/LVU_Unit-UAF.xml
cp %{SourceDir}/AddService/MMG/MMG-SAF.xml %{_sourcedir}%{SwimKits}/AddServiceUtil/MMG/MMG-SAF.xml
cp %{SourceDir}/AddService/MMG/NDU-IS3_Group-UAF.xml %{_sourcedir}%{SwimKits}/AddServiceUtil/MMG/NDU-IS3_Group-UAF.xml
cp %{SourceDir}/AddService/MMG/OMU_Group-UAF.xml %{_sourcedir}%{SwimKits}/AddServiceUtil/MMG/OMU_Group-UAF.xml
cp %{SourceDir}/AddService/MMG/SMU_Group-UAF.xml %{_sourcedir}%{SwimKits}/AddServiceUtil/MMG/SMU_Group-UAF.xml
cp %{SourceDir}/AddService/MMG/TRM_Group-UAF.xml %{_sourcedir}%{SwimKits}/AddServiceUtil/MMG/TRM_Group-UAF.xml
cp %{SourceDir}/AddService/MMG/Vm-Asu-UAF.xml    %{_sourcedir}%{SwimKits}/AddServiceUtil/MMG/Vm-Asu-UAF.xml
cp %{SourceDir}/AddService/VI/VI-SAF.xml %{_sourcedir}%{SwimKits}/AddServiceUtil/VI/VI-SAF.xml
cp %{SourceDir}/Common/Demo/CAS-UAF.xml %{_sourcedir}%{SwimKits}/CreateSystem/Demo/CAS-UAF.xml

%build

%pre

%files
%defattr(644,swim,swim)
%attr(755,swim,swim) %dir %{SwimKits}/CreateSystem/NDU-WHC
%attr(755,swim,swim) %dir %{SwimKits}/CreateSystem/MMG
%attr(755,swim,swim) %dir %{SwimKits}/CreateSystem/VI
%attr(755,swim,swim) %dir %{SwimSys}/SwimManger
%{SwimKits}/AddServiceUtil/NDU-WHC/DSU_Group-UAF.xml
%{SwimKits}/AddServiceUtil/NDU-WHC/LVU_Group-UAF.xml
%{SwimKits}/AddServiceUtil/NDU-WHC/OMU_Group-UAF.xml
%{SwimKits}/AddServiceUtil/NDU-WHC/SMU_Group-UAF.xml
%{SwimKits}/AddServiceUtil/NDU-WHC/VM_ASU_Group-UAF.xml
%{SwimKits}/AddServiceUtil/NDU-WHC/NDU-WHC-SAF.xml
%{SwimKits}/AddServiceUtil/MMG/DSU_Group-UAF.xml
%{SwimKits}/AddServiceUtil/MMG/IS3_CMD_Unit-UAF.xml
%{SwimKits}/AddServiceUtil/MMG/LVU_Unit-UAF.xml
%{SwimKits}/AddServiceUtil/MMG/MMG-SAF.xml
%{SwimKits}/AddServiceUtil/MMG/NDU-IS3_Group-UAF.xml
%{SwimKits}/AddServiceUtil/MMG/OMU_Group-UAF.xml
%{SwimKits}/AddServiceUtil/MMG/SMU_Group-UAF.xml
%{SwimKits}/AddServiceUtil/MMG/TRM_Group-UAF.xml
%{SwimKits}/AddServiceUtil/MMG/Vm-Asu-UAF.xml
%{SwimKits}/AddServiceUtil/VI/VI-SAF.xml
%{SwimKits}/AddServiceUtil/createSystem-CAF.xml
%{SwimKits}/CreateSystem/MMG_UnitMap.csv
%{SwimKits}/CreateSystem/Demo_UnitMap.csv
%{SwimKits}/CreateSystem/NDU-WHC_UnitMap.csv
%{SwimKits}/CreateSystem/VI_UnitMap.csv
%{SwimKits}/CreateSystem/NDU-WHC/NDU-UAF.xml
%{SwimKits}/CreateSystem/createSystem-CAF.xml
%{SwimKits}/CreateSystem/VI/CAS_Group-UAF.xml
%{SwimKits}/CreateSystem/VI/GenVI-SAF.xml
%{SwimKits}/CreateSystem/VI/MTS_Group-UAF.xml
%{SwimKits}/CreateSystem/VI/PROXY_Group-UAF.xml
%{SwimKits}/CreateSystem/MMG/MMG_AddOns-SAF.xml
%{SwimKits}/CreateSystem/MMG/MMSGW-UAF.xml
%{SwimKits}/CreateSystem/MMG/NDU_WHC-UAF.xml
%{SwimKits}/CreateSystem/MMG/PROXY-UAF.xml
%{SwimKits}/CreateSystem/MMG/MTS_Group-UAF.xml
%{SwimKits}/CreateSystem/Demo/CAS-UAF.xml
%{SwimSys}/SwimManger/UnitGroup.xml
%{SwimSys}/SwimManger/SwimManager_Linux-UAF.xml
%attr(755,swim,swim) %{SwimKits}/CreateSystem/BuildSwimSystem.pl
%attr(755,swim,swim) %{SwimKits}/CreateSystem/BuildCvl.pl
%attr(755,swim,swim) %{SwimKits}/AddServiceUtil/scripts/CreatSys.pl
%attr(755,swim,swim) %{SwimKits}/AddServiceUtil/scripts/CreatAddServiceSys.pl

%define _rpmdir %{Target}

%post
HOSTNAME=`hostname`
HOSTIP=`hostname -i`
UNITFILE=/var/cti/data/swim/systems/SwimManger/UnitGroup.xml
perl -pi -e 's/UnitName=".+?"/UnitName="$ARGV[1]"/;' -e 's/Ip=".+?"/Ip="$ARGV[0]"/' $UNITFILE $HOSTIP $HOSTNAME 2> /tmp/InstallPkg.log || cat /tmp/InstallPkg.log

%preun

%postun
