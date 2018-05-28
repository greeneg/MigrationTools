#!/usr/bin/perl
#
# $Id: migrate_hosts.pl,v 1.5 2003/04/15 03:09:34 lukeh Exp $
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
# hosts migration tool
#
#

use strict;
use warnings;

use File::Basename;

use lib './lib';
use MigrationTools::Common;

my sub dump_host {
    my ($fh, $hostaddr, $hostname, $_aliases, $basedn) = @_;

    my $dn;
    my @aliases = @{$_aliases};

	return if (!$hostaddr);

	print $fh "dn: cn=$hostname,$basedn,$DEFAULT_BASE\n";
	print $fh "objectClass: top\n";
	print $fh "objectClass: ipHost\n";
	print $fh "objectClass: device\n";
	print $fh "ipHostNumber: $hostaddr\n";
	print $fh "cn: $hostname\n";
	@aliases = uniq($hostname, @aliases);
	foreach my $alias (@aliases) {
		if ($alias ne $hostname) {
			print $fh "cn: $alias\n";
		}
	}
	print $fh "\n";
}

my sub process_localhosts {
    my ($use_stdout, $in_fh, $out_fh, $basedn, @localhosts) = @_;

    # now lets deal with the localhost stuff first
    foreach my $lh (@localhosts) {
        my @new_aliases;
        my ($addr, $hn, @aliases) = split(/\s+/, $lh);
        # some hosts are incorrectly configured to call the IPv6 local address
        # localhost, when it should be ip6-localhost, and localhost should be
        # an alias.
        my $t_addr;
        if ($addr eq '::1') {
            $hn = 'ipv6-localhost';
            # remove ipv6-localhost as an alias
            foreach my $alias (@aliases) {
                next if ($alias eq "ipv6-localhost");
                push(@new_aliases, $alias);
            }
            # ensure that locahost is an alias
            push(@new_aliases, 'localhost');
        }
        if ($use_stdout) {
            dump_host(\*STDOUT, $addr, $hn, \@new_aliases, $basedn);
        } else {
            dump_host($out_fh, $addr, $hn, \@new_aliases, $basedn);
        }
    }
}

my sub process_hosts {
    my ($use_stdout, $in_fh, $out_fh, $basedn, @hosts) = @_;

    foreach my $host (@hosts) {
        my ($hostaddr, $hostname, @aliases) = split(/\s+/, $host);
	
        if ($use_stdout) {
            dump_host(\*STDOUT, $hostaddr, $hostname, \@aliases, $basedn);
        } else {
            dump_host($out_fh, $hostaddr, $hostname, \@aliases, $basedn);
        }
    }
}

our sub main {
    my $program = basename($0);
    my $basedn = getsuffix($program);

    my ($in, $out) = parse_args(@ARGV);
    my ($use_stdout, $in_fh, $out_fh) = open_files($in, $out);

    # this one needs done differently than the other NSS files. The issue is
    # due to IPv6 hosts and how they alias localhost to both a v4 and v6
    # address. Due to this, read in the FULL file, then process the spacial
    # case, then walk the others
    my @hosts;
    my @localhosts;
    foreach my $l (<$in_fh>) {
        next if ($l =~ /^#/ || $l =~ /^\n/);
        chomp $l;
        # special case for localhost stuff
        if ($l =~ /\s+localhost/) {
            push(@localhosts, $l);
        } else {
            push(@hosts, $l);
        }
    }

    process_localhosts($use_stdout, $in_fh, $out_fh, $basedn, @localhosts);
    process_hosts($use_stdout, $in_fh, $out_fh, $basedn, @hosts);

    close($in_fh);
    if (defined($out_fh)) {
        close($out_fh);
    }
}

main();