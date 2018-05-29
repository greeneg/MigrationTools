#!/usr/bin/perl
#
# $Id: migrate_rpc.pl,v 1.6 2003/04/15 03:09:34 lukeh Exp $
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
# Rpc migration tool
#
#

use strict;
use warnings;

use File::Basename;

use lib './lib';
use MigrationTools::Common;

my sub dump_rpc {
	my ($fh, $rpcname, $rpcnumber, $basedn, @aliases) = @_;

	return if (! $rpcname);

	print $fh "dn: cn=$rpcname,$basedn,$DEFAULT_BASE\n";
	print $fh "objectClass: oncRpc\n";
	print $fh "objectClass: top\n";
	# workaround typo in RFC 2307 where description
	# was made MUST instead of MAY
	print $fh "description: RPC $rpcname\n";
	print $fh "oncRpcNumber: $rpcnumber\n";
	print $fh "cn: $rpcname\n";
	@aliases = uniq($rpcname, @aliases);
	foreach my $alias (@aliases) {
		print $fh "cn: $alias\n";
	}
	print $fh "\n";
}

our sub main {
    my $program = basename($0);
    my $basedn = getsuffix($program);

    my ($in, $out) = parse_args(@ARGV);
    my ($use_stdout, $in_fh, $out_fh) = open_files($in, $out);

    foreach my $line (<$in_fh>) {
        chomp $line;
        next unless ($line);
        next if ($line =~ /^#/);
        $line =~ s/#(.*)$//;

        my ($rpcname, $rpcnumber, @aliases) = split(/\s+/, $line);

        if ($use_stdout) {
            dump_rpc(\*STDOUT, $rpcname, $rpcnumber, $basedn, @aliases);
        } else {
            dump_rpc($out_fh, $rpcname, $rpcnumber, $basedn, @aliases);
        }
    }

    close $in_fh;
    if (defined($out_fh)) {
        close $out_fh;
    }
}

main();
