%define Target %{ViewDir}/Build/Install/bin
%define SourceDir %{ViewDir}/Build
%define ProfDir /usr/cti/conf/profiledefinition


#Disable the uppackage file termination:
#%define _unpackaged_files_terminate_build 0

#Disable the binary stripping:
%define __os_install_post %{nil}

Name:		%{_rpm_name}
Version:	%{_rpm_version}
Release:	%{_rpm_stf}
License:		Copyright 2013 Comverse, Inc. All rights reserved
Vendor:			Comverse Inc.
Group:			Applications/System
URL:			http://www.comverse.com/
Packager:		Comverse SCM, <scm@comverse.com>
AutoReqProv: 	off
buildroot: $RPM_BUILD_ROOT


Summary:		%{product} ...

%description
%{_rpm_name} Profile Definition - for WHC Service
Revision:	%{_rpm_revision}


%prep
# Tasks for rpm creation
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT%{ProfDir}
mkdir -p %{Target}
cp %{SourceDir}/ProfFiles/ProfileDefinitions_WHC.xml 		$RPM_BUILD_ROOT%{ProfDir}/ProfileDefinitions_WHC.xml
cp %{SourceDir}/ProfFiles/ProfileDefinitions_WHC-BWList.xml 	$RPM_BUILD_ROOT%{ProfDir}/ProfileDefinitions_WHC-BWList.xml
cp %{SourceDir}/ProfFiles/ProfileDefinitions_SmartCall.xml 	$RPM_BUILD_ROOT%{ProfDir}/ProfileDefinitions_SmartCall.xml
cp %{SourceDir}/ProfFiles/ProfileDefinitions_CallScreening.xml 	$RPM_BUILD_ROOT%{ProfDir}/ProfileDefinitions_CallScreening.xml

%build

## %install
#install -d  $RPM_BUILD_ROOT/...
#install	    %{view_workspace}/...		$RPM_BUILD_ROOT/...
## echo "Ignore Install Processs ..."

%pre
if [ "$1" = "1" ]; then

  # Tasks for scratch installation

elif [ "$1" = "2" ]; then

  #  Tasks for upgrade  installation

fi

%post
if [ "$1" = "1" ]; then

  # Tasks for scratch installation

elif [ "$1" = "2" ]; then

  #  Tasks for upgrade  installation

fi

%files
%defattr(644,root,root)
%{ProfDir}/ProfileDefinitions_WHC.xml
%{ProfDir}/ProfileDefinitions_WHC-BWList.xml
%{ProfDir}/ProfileDefinitions_SmartCall.xml
%{ProfDir}/ProfileDefinitions_CallScreening.xml
%define _rpmdir %{Target}

