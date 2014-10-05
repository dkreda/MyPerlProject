%define Target %{ViewDir}/Kit
%define SourceDir %{ViewDir}
%define InstDir /var/tmp/SWIMUtilDemo

Summary:	SWIM Utilities Demo
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
%{_rpm_name} SWIM Utilities Demo
Revision:	%{_rpm_revision}

%prep
rm -rf %{_sourcedir}
mkdir -p %{_sourcedir}%{InstDir}
mkdir -p %{Target}
cp %{SourceDir}/SwimVerify.pl 	%{_sourcedir}/%{InstDir}/SwimVerify.pl
cp %{SourceDir}/Fonts.conf 	%{_sourcedir}/%{InstDir}/Fonts.conf
cp %{SourceDir}/SetSwimSys.pl 	%{_sourcedir}/%{InstDir}/SetSwimSys.pl
cp %{SourceDir}/mdbReader.pm 	%{_sourcedir}/%{InstDir}/mdbReader.pm
cp %{SourceDir}/TestMissedCaf.pl %{_sourcedir}/%{InstDir}/TestMissedCaf.pl
cp %{SourceDir}/Octopus2Swim.pl %{_sourcedir}/%{InstDir}/Octopus2Swim.pl
cp %{SourceDir}/Octopu2Twim.csv %{_sourcedir}/%{InstDir}/Octopu2Twim.csv

%build

%pre

%files
%defattr(644,root,root)
%{InstDir}/Octopu2Twim.csv
%{InstDir}/Fonts.conf
%defattr(755,root,root)
%{InstDir}/SwimVerify.pl
%{InstDir}/SetSwimSys.pl
%{InstDir}/mdbReader.pm
%{InstDir}/TestMissedCaf.pl
%{InstDir}/Octopus2Swim.pl

%define _rpmdir %{Target}

%post

%preun

%postun
