%define Target %{ViewDir}/Build/Install/bin
%define SourceDir %{ViewDir}/Build
%define ProfDir /usr/cti/conf/profiledefinition

Summary:	Profile Definition - for WHC Service
Name:		%{_rpm_name}
Version:	%{_rpm_version}
Release:	%{_rpm_stf}
License:	Free
Vendor:		Comverse Inc
Group:		Applications/Swim
URL:		http://boo.com
Packager:	Anonymous
buildroot: %{_sourcedir}
AutoReqProv: no

%description
%{_rpm_name} Profile Definition - for WHC Service
Revision:	%{_rpm_revision}

%prep
rm -rf %{_sourcedir}
mkdir -p %{_sourcedir}%{ProfDir}
mkdir -p %{Target}
cp %{SourceDir}/ProfFiles/ProfileDefinitions_WHC.xml 		%{_sourcedir}%{ProfDir}/ProfileDefinitions_WHC.xml
cp %{SourceDir}/ProfFiles/ProfileDefinitions_WHC-BWList.xml 	%{_sourcedir}%{ProfDir}/ProfileDefinitions_WHC-BWList.xml
cp %{SourceDir}/ProfFiles/ProfileDefinitions_SmartCall.xml 	%{_sourcedir}%{ProfDir}/ProfileDefinitions_SmartCall.xml
cp %{SourceDir}/ProfFiles/ProfileDefinitions_CallScreening.xml 	%{_sourcedir}%{ProfDir}/ProfileDefinitions_CallScreening.xml

%build

%pre

%files
%defattr(644,root,root)
%{ProfDir}/ProfileDefinitions_WHC.xml
%{ProfDir}/ProfileDefinitions_WHC-BWList.xml
%{ProfDir}/ProfileDefinitions_SmartCall.xml
%{ProfDir}/ProfileDefinitions_CallScreening.xml
%define _rpmdir %{Target}

%post

%preun

%postun
