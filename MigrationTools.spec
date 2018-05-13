Summary: Migration scripts for LDAP
Name:      MigrationTools
Version:   42
Release:   1
Source:    ftp://ftp.padl.com/pub/%{name}-%{version}.tar.gz
URL:       http://www.padl.com/
Copyright: BSD
Group: Networking/Utilities
BuildRoot: /tmp/rpm-%{name}-root
Prefix: /usr/local

%description
The MigrationTools are a set of Perl scripts for migrating users, groups,
aliases, hosts, netgroups, networks, protocols, RPCs, and services from 
existing nameservices (flat files, NIS, and NetInfo) to LDAP. 

%prep
export RPM_BUILD_ROOT
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/usr/local/%{name}

%setup

%build

%install
cp -a migrate_* $RPM_BUILD_ROOT/usr/local/%{name}

%clean
rm -rf $RPM_BUILD_ROOT

%files
/usr/local/%{name}

%doc README
