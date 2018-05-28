#!/usr/bin/perl
#
# $Id: migrate_networks.pl,v 1.5 2003/04/15 03:09:34 lukeh Exp $
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
# networks migration tool
#
#

use strict;
use warnings;

use File::Basename;

use lib './lib';
use MigrationTools::Common;

sub dump_network {
    my ($fh, $networkaddr, $networkname, $_aliases, $basedn) = @_;
    my @aliases = @{$_aliases};

	my ($dn, $revnetwork);
	return if (!$networkaddr);

	my $cn = $networkname; # could be $revnetwork

	print $fh "dn: cn=$networkname,$basedn,$DEFAULT_BASE\n";
	print $fh "objectClass: ipNetwork\n";
	print $fh "objectClass: top\n";
	print $fh "ipNetworkNumber: $networkaddr\n";
	print $fh "cn: $networkname\n";
	@aliases = uniq($networkname, @aliases);
	foreach my $alias (@aliases) {
		if ($alias ne $networkname) {
			print $fh "cn: $_\n";
		}
	}
	print $fh "\n";
}

our sub main {
    my $program = basename($0);
    my $basedn = getsuffix($program);

    my ($in, $out) = parse_args(@ARGV);
    my ($use_stdout, $in_fh, $out_fh) = open_files($in, $out);

    foreach my $network (<$in_fh>) {
        next if ($network =~ /^#/ || $network =~ /^\n/);
        my ($networkname, $networkaddr, @aliases) = split(/\s+/, $network);

        if ($use_stdout) {
            dump_network(\*STDOUT, $networkaddr, $networkname, \@aliases, $basedn);
        } else {
            dump_network($out_fh, $networkaddr, $networkname, \@aliases, $basedn);
        }
    }

    close($in_fh);
    if (defined($out_fh)) {
        close($out_fh);
    }
}

main();
