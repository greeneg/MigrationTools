#!/usr/bin/perl
#
# $Id: migrate_group.pl,v 1.7 2003/04/15 03:09:33 lukeh Exp $
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
# Group migration tool
#
#

use strict;
use warnings;

use feature ":5.24";

use File::Basename;

use lib './lib';
use MigrationTools::Common;

my sub dump_group {
    my ($fh, $group, $pwd, $gid, $users, $basedn) = @_;

    my @members = split(/,/, $users);

    print $fh "dn: cn=$group,$basedn,$DEFAULT_BASE\n";
    print $fh "objectClass: posixGroup\n";
    print $fh "objectClass: top\n";
    print $fh "cn: $group\n";
    unless ($pwd ne 'x' || $pwd ne '!') {
        print $fh "userPassword: {crypt}$pwd\n";
    }

    print $fh "gidNumber: $gid\n";

    @members = uniq($group, @members);
    foreach my $member (@members) {
        print $fh "memberUid: $member\n";
    }

    print $fh "\n";
}

our sub main {
    my $program = basename($0);
    my $basedn = getsuffix($program);

    my ($in, $out) = parse_args(@ARGV);
    my ($use_stdout, $in_fh, $out_fh) = open_files($in, $out);

    while(<$in_fh>) {
        chomp;
        next if /^#/;
        next if /^\+/;

        my ($group, $pwd, $gid, $users) = split(/:/);
        if ($use_stdout) {
            dump_group(\*STDOUT, $group, $pwd, $gid, $users, $basedn);
        } else {
            dump_group($out_fh, $group, $pwd, $gid, $users, $basedn);
        }
    }

    close($in_fh);
    if (defined($out_fh)) {
        close($out_fh);
    }
}

main();
