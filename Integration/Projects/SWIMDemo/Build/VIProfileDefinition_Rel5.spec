%define Target %{ViewDir}/Build/Install/bin
%define SourceDir %{ViewDir}/Build
%define ProfDir /usr/cti/conf/profiledefinition

Summary:	Profile Definition - for VI Service
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
%{_rpm_name} Profile Definition - for VI Service
Revision:	%{_rpm_revision}

%prep
rm -rf %{_sourcedir}
mkdir -p %{_sourcedir}%{ProfDir}
mkdir -p %{Target}
cp %{SourceDir}/ProfFiles/ProfileDefinitions_VI.xml 		%{_sourcedir}%{ProfDir}/ProfileDefinitions_VI.xml

%build

%pre

%files
%defattr(644,root,root)
%{ProfDir}/ProfileDefinitions_VI.xml
%define _rpmdir %{Target}

%post

%preun

%postun
