#
# $Id: migrate_common.ph,v 1.22 2003/04/15 03:09:33 lukeh Exp $
#
# Copyright (c) 1997-2003 Luke Howard.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. All advertising materials mentioning features or use of this software
#    must display the following acknowledgement:
#        This product includes software developed by Luke Howard.
# 4. The name of the other may not be used to endorse or promote products
#    derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE LUKE HOWARD ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL LUKE HOWARD BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#

#
# Common defines for MigrationTools
#

package MigrationTools::Common;

use strict;
use warnings;

use feature ":5.24";

use Config::IniFiles;
use File::Basename;
use Cwd;

use Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(
    $DEFAULT_MAIL_DOMAIN
    $DEFAULT_BASE
    $DEFAULT_MAIL_HOST
    $DEFAULT_OWNER
    $DEFAULT_REALM
    $EXTENDED_SCHEMA
    escape_metacharacters
    getsuffix
    get_nc
    get_classmap
    ldif_entry
    open_files
    parse_args
    uniq
);

# load our configuration file
my $prefix = getcwd();
my $cfg = Config::IniFiles->new(
    -file => "$prefix/config.ini",
    -default => "Defaults",
);

# default owner
our $DEFAULT_OWNER;

# default Krb5 realm
our $DEFAULT_REALM = $cfg->val('Defaults', 'Krb5_Realm');

# Default DNS domain
our $DEFAULT_MAIL_DOMAIN = $cfg->val('Defaults', 'Mail_Domain');

# Default base 
our $DEFAULT_BASE = $cfg->val('Defaults', 'Base');

# where /etc/mail/ldapdomains contains names of ldap_routed
# domains (similiar to MASQUERADE_DOMAIN_FILE).
our $DEFAULT_MAIL_HOST = $cfg->val('Defaults', 'Mail_Host');

# turn this on to support more general object clases
# such as person.
our $EXTENDED_SCHEMA = $cfg->val('Defaults', 'Extended_Schema');

# Naming contexts. Key is $PROGRAM with migrate_ and .pl 
# stripped off. 
my $NETINFOBRIDGE = (-x "/usr/sbin/mkslapdconf");

my $ds_type = "Midgard";

our %NAMINGCONTEXT;
if ($NETINFOBRIDGE) {
	$NAMINGCONTEXT{'aliases'}           = "cn=aliases";
	$NAMINGCONTEXT{'fstab'}             = "cn=mounts";
	$NAMINGCONTEXT{'passwd'}            = "cn=users";
	$NAMINGCONTEXT{'netgroup_byuser'}   = "cn=netgroup.byuser";
	$NAMINGCONTEXT{'netgroup_byhost'}   = "cn=netgroup.byhost";
	$NAMINGCONTEXT{'group'}             = "cn=groups";
	$NAMINGCONTEXT{'netgroup'}          = "cn=netgroup";
	$NAMINGCONTEXT{'hosts'}             = "cn=machines";
	$NAMINGCONTEXT{'networks'}          = "cn=networks";
	$NAMINGCONTEXT{'protocols'}         = "cn=protocols";
	$NAMINGCONTEXT{'rpc'}               = "cn=rpcs";
	$NAMINGCONTEXT{'services'}          = "cn=services";
} elsif (ds_type() eq "Midgard") {
    $NAMINGCONTEXT{'aliases'}           = "cn=Aliases";
    $NAMINGCONTEXT{'fstab'}             = "cn=Mounts";
    $NAMINGCONTEXT{'passwd'}            = "cn=Users";
    $NAMINGCONTEXT{'netgroup_byuser'}   = "nisMapName=netgroup.byuser";
    $NAMINGCONTEXT{'netgroup_byhost'}   = "nisMapName=netgroup.byhost";
    $NAMINGCONTEXT{'group'}             = "cn=Groups";
    $NAMINGCONTEXT{'netgroup'}          = "cn=Netgroups";
    $NAMINGCONTEXT{'hosts'}             = "cn=Computers";
    $NAMINGCONTEXT{'networks'}          = "cn=Networks";
    $NAMINGCONTEXT{'protocols'}         = "cn=Protocols";
    $NAMINGCONTEXT{'rpc'}               = "cn=Rpc";
    $NAMINGCONTEXT{'services'}          = "cn=Services";
    $NAMINGCONTEXT{'cfgmgmt'}           = "cn=MDSS";
} else {
	$NAMINGCONTEXT{'aliases'}           = "ou=Aliases";
	$NAMINGCONTEXT{'fstab'}             = "ou=Mounts";
	$NAMINGCONTEXT{'passwd'}            = "ou=People";
	$NAMINGCONTEXT{'netgroup_byuser'}   = "nisMapName=netgroup.byuser";
	$NAMINGCONTEXT{'netgroup_byhost'}   = "nisMapName=netgroup.byhost";
	$NAMINGCONTEXT{'group'}             = "ou=Group";
	$NAMINGCONTEXT{'netgroup'}          = "ou=Netgroup";
	$NAMINGCONTEXT{'hosts'}             = "ou=Hosts";
	$NAMINGCONTEXT{'networks'}          = "ou=Networks";
	$NAMINGCONTEXT{'protocols'}         = "ou=Protocols";
	$NAMINGCONTEXT{'rpc'}               = "ou=Rpc";
	$NAMINGCONTEXT{'services'}          = "ou=Services";
}

# Turn this on for inetLocalMailReceipient
# sendmail support; add the following to 
# sendmail.mc (thanks to Petr@Kristof.CZ):
##### CUT HERE #####
#define(`confLDAP_DEFAULT_SPEC',`-h "ldap.padl.com"')dnl
#LDAPROUTE_DOMAIN_FILE(`/etc/mail/ldapdomains')dnl
#FEATURE(ldap_routing)dnl
##### CUT HERE #####

#
# allow environment variables to override predefines
#
if (defined($ENV{'LDAP_BASEDN'})) {
    $DEFAULT_BASE = $ENV{'LDAP_BASEDN'};
}

if (defined($ENV{'LDAP_DEFAULT_MAIL_DOMAIN'})) {
    $DEFAULT_MAIL_DOMAIN = $ENV{'LDAP_DEFAULT_MAIL_DOMAIN'};
}

if (defined($ENV{'LDAP_DEFAULT_MAIL_HOST'})) {
    $DEFAULT_MAIL_HOST = $ENV{'LDAP_DEFAULT_MAIL_HOST'};
}

# binddn used for alias owner (otherwise uid=root,...)
if (defined($ENV{'LDAP_BINDDN'})) {
    $DEFAULT_OWNER = $ENV{'LDAP_BINDDN'};
}

if (defined($ENV{'LDAP_EXTENDED_SCHEMA'})) {
	$EXTENDED_SCHEMA = $ENV{'LDAP_EXTENDED_SCHEMA'};
}

# If we haven't set the default base, guess it automagically.
if (!defined($DEFAULT_BASE)) {
	$DEFAULT_BASE = domain_expand($DEFAULT_MAIL_DOMAIN);
	$DEFAULT_BASE =~ s/,$//o;
}

# Default Kerberos realm
if ($EXTENDED_SCHEMA) {
	$DEFAULT_REALM = $DEFAULT_MAIL_DOMAIN;
	$DEFAULT_REALM =~ tr/a-z/A-Z/;
}

# now that environment stuff is done, define our base
$NAMINGCONTEXT{'base'} = $DEFAULT_BASE;

my $REVNETGROUP;
if (-x "/usr/sbin/revnetgroup") {
	$REVNETGROUP = "/usr/sbin/revnetgroup";
} elsif (-x "/usr/lib/yp/revnetgroup") {
	$REVNETGROUP = "/usr/lib/yp/revnetgroup";
}

my %classmap;
$classmap{'o'} = 'organization';
$classmap{'dc'} = 'domain';
$classmap{'l'} = 'locality';
$classmap{'ou'} = 'organizationalUnit';
$classmap{'c'} = 'country';
$classmap{'nismapname'} = 'nisMap';
$classmap{'cn'} = 'container';

# we need our base name
our $program = basename($0);

sub ds_type {
    return $ds_type;
}

sub parse_args {
    my @args = @_;

	if ($#args < 0) {
		print STDERR "Usage: $program infile [outfile]\n";
		exit 1;
	}
	
	my $in = $args[0];
	
	if ($#args > 0) {
		my $out = $args[1];
        return $in, $out;
	}

    return $in;
}

sub open_files {
    my ($in, $out) = @_;

    my $use_stdout;

	open(my $in_fh, $in);
	if (defined($out)) {
		open(my $out_fh, '>', $out);
		$use_stdout = 0;
        return $use_stdout, $in_fh, $out_fh;
	} else {
		$use_stdout = 1;
        return $use_stdout, $in_fh;
	}
}

# moved from migrate_hosts.pl
# lukeh 10/30/97
sub domain_expand {
	my $first = 1;
    my $dn;
	my @namecomponents = split(/\./, $_[0]);
	foreach $_ (@namecomponents) {
		$first = 0;
		$dn .= "dc=$_,";
	}
	$dn .= $DEFAULT_BASE;
	return $dn;
}

# case insensitive unique
sub uniq {
	my $name = shift;
	my @list = @_;

	my @ret;

	my $next;
    my $last = "";
	foreach $next (@list) {
		if (uc($next) ne uc($last) &&
		    uc($next) ne uc($name)) {
			push (@ret, $next);
		}
		$last = $next;
	}

	return @ret;
}

# concatenate naming context and 
# organizational base
sub getsuffix {
	my $program = shift;
	my $nc;

	$program =~ s/^migrate_(.*)\.pl$/$1/;
	return $nc = $NAMINGCONTEXT{$program};
}

sub ldif_entry {
    # remove leading, trailing whitespace
	my ($HANDLE, $lhs, $rhs) = @_;
	my ($type, $val) = split(/\=/, $lhs);

    my $dn;
    if ($rhs ne "") {
        $dn = $lhs . ',' . $rhs;
    } else {
        $dn = $lhs;
    }

	$type =~ s/\s*$//o;
	$type =~ s/^\s*//o;
	$type =~ tr/A-Z/a-z/;
	$val =~ s/\s*$//o;
	$val =~ s/^\s*//o;

	print $HANDLE "dn: $dn\n";
	print $HANDLE "$type: $val\n";
	print $HANDLE "objectClass: top\n";
	print $HANDLE "objectClass: $classmap{$type}\n";
	if ($EXTENDED_SCHEMA) {
		if ($DEFAULT_MAIL_DOMAIN) {
			print $HANDLE "objectClass: domainRelatedObject\n";
			print $HANDLE "associatedDomain: $DEFAULT_MAIL_DOMAIN\n";
		}
	}

	print $HANDLE "\n";
}

# Added Thu Jun 20 16:40:28 CDT 2002 by Bob Apthorpe
# <apthorpe@cynistar.net> to solve problems with embedded plusses in
# protocols and mail aliases.
sub escape_metacharacters {
    my $name = shift;

	# From Table 3.1 "Characters Requiring Quoting When Contained
	# in Distinguished Names", p87 "Understanding and Deploying LDAP
	# Directory Services", Howes, Smith, & Good.

	# 1) Quote backslash
	# Note: none of these are very elegant or robust and may cause
	# more trouble than they're worth. That's why they're disabled.
	# 1.a) naive (escape all backslashes)
	# $name =~ s#\\#\\\\#og;
	#
	# 1.b) mostly naive (escape all backslashes not followed by
	# a backslash)
	# $name =~ s#\\(?!\\)#\\\\#og;
	#
	# 1.c) less naive and utterly gruesome (replace solitary
	# backslashes)
	# $name =~ s{		# Replace
	#		(?<!\\) # negative lookbehind (no preceding backslash)
	#		\\	# a single backslash
	#		(?!\\)	# negative lookahead (no following backslash)
	#	}
	#	{		# With
	#		\\\\	# a pair of backslashes
	#	}gx;
	# Ugh. Note that s#(?:[^\\])\\(?:[^\\])#////#g fails if $name
	# starts or ends with a backslash. This expression won't work
	# under perl4 because the /x flag and negative lookahead and
	# lookbehind operations aren't supported. Sorry. Also note that
	# s#(?:[^\\]*)\\(?:[^\\]*)#////#g won't work either.  Of course,
	# this is all broken if $name is already escaped before we get
	# to it. Best to throw a warning and make the user import these
	# records by hand.

	# 2) Quote leading and trailing spaces
	my ($leader, $body, $trailer) = ();
	if (($leader, $body, $trailer) = ($name =~ m|^( *)(.*\S)( *)$|o)) {
		$leader =~ s| |\\ |og;
		$trailer =~ s| |\\ |og;
		$name = $leader . $body . $trailer;
	}

	# 3) Quote leading octothorpe (#)
	$name =~ s|^#|\\#|o;

	# 4) Quote comma, plus, double-quote, less-than, greater-than,
	# and semicolon
	$name =~ s|([,+"<>;])|\\$1|g;

	return $name;
}

sub get_nc {
    return %NAMINGCONTEXT;
}

sub get_classmap {
    return %classmap;
}

1;
