%define Target %{ViewDir}/Build/Install/bin
%define SourceDir %{ViewDir}/Build
%define ProfDir /usr/cti/conf/profiledefinition

Summary:	Profile Definition - for MMG Services (VM2Text and VM2MMS)
Name:		%{_rpm_name}
Version:	%{_rpm_version}
Release:	%{_rpm_stf}
License:	Free
Vendor:		Comverse Inc
Group:		Applications
URL:		http://comverse.com
Packager:	Anonymous
buildroot: %{_sourcedir}
AutoReqProv: no

%description
%{_rpm_name} Profile Definition - for MMG Services (VM2Text and VM2MMS)
Revision:	%{_rpm_revision}

%prep
rm -rf %{_sourcedir}
mkdir -p %{_sourcedir}%{ProfDir}
mkdir -p %{Target}
cp %{SourceDir}/ProfFiles/ProfileDefinitions_VW_IS4.xml		%{_sourcedir}%{ProfDir}/ProfileDefinitions_VW_IS4.xml
cp %{SourceDir}/ProfFiles/ProfileDefinitions_VM2MMS_IS4.xml 	%{_sourcedir}%{ProfDir}/ProfileDefinitions_VM2MMS_IS4.xml

%build

%pre

%files
%defattr(644,root,root)
%{ProfDir}/ProfileDefinitions_VW_IS4.xml
%{ProfDir}/ProfileDefinitions_VM2MMS_IS4.xml

%define _rpmdir %{Target}

%post

%preun

%postun
