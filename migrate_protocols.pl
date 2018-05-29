#!/usr/bin/perl
#
# $Id: migrate_protocols.pl,v 1.7 2003/04/15 03:09:34 lukeh Exp $
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
# protocol migration tool
#
#

use strict;
use warnings;

use feature ":5.24";

use File::Basename;

use lib './lib';
use MigrationTools::Common;

my sub dump_protocol {
    my ($fh, $name, $number, $alias, $description, $basedn) = @_;
    return if $name eq "use";

    my @aliases = @{$alias};

    my $dname = escape_metacharacters($name);
    print $fh "dn: cn=$dname,$basedn,$DEFAULT_BASE\n";
    print $fh "objectClass: ipProtocol\n";
    print $fh "objectClass: top\n";
    # workaround typo in RFC 2307 where description
    # was made MUST instead of MAY
    print $fh "description: $description\n";
    print $fh "ipProtocolNumber: $number\n";
    print $fh "cn: $name\n";
    @aliases = uniq($name, @aliases);
    foreach my $_alias (@aliases) {
        $_alias = uc($_alias);
        print $fh "cn: $_alias\n";
    }
    print $fh "\n";
}

our sub main {
    my $program = basename($0);
    my $basedn = getsuffix($program);

    my ($in, $out) = parse_args(@ARGV);
    my ($use_stdout, $in_fh, $out_fh) = open_files($in, $out);

    # read file in, sort them then process
    my @lines;
    foreach my $line (<$in_fh>) {
        chomp $line;
        next unless ($line);
        next if ($line =~ /^#/);

        push(@lines, $line);        
    }
    foreach my $line (sort @lines) {
        my ($proto_fields, $description) = split(/# /, $line);
        my ($name, $number, @aliases) = split(/\s+/, $proto_fields);

        if ($use_stdout) {
            dump_protocol(\*STDOUT, $name, $number, \@aliases, $description, $basedn);
        } else {
            dump_protocol($out_fh, $name, $number, \@aliases, $description, $basedn);
        }
    }

    close $in_fh;
    if (defined($out_fh)) {
        close $out_fh;
    }
}

main();
