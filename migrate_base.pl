#!/usr/bin/perl
#
# Copyright (c) 2018 Gary Greene
#
# Forked from the original version from PADL
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
#
# LDIF entries for base DN
#
#

use strict;
use warnings;

# we really shouldn't try running this on ancient perl interpreters as we
# use lexical subs, which are available in newer perl versions only
use feature ":5.24";

use File::Basename;
use Net::Domain::TLD qw(tlds);

use lib "./lib";
use MigrationTools::Common;

my sub gen_namingcontexts {
    my $basedn = shift;
    my %naming_context = @_;

    # uniq naming contexts
    my (@ncs, $map, $nc);
    foreach $map (keys %naming_context) {
        next if $map eq 'base';
        next if $map eq 'netgroup_byuser';
        next if $map eq 'netgroup_byhost';
        $nc = $naming_context{$map};
        if (! grep(/^$nc$/, @ncs)) {
            push(@ncs, $nc);
            ldif_entry(\*STDOUT, $nc, $DEFAULT_BASE);
        }
    }
}

my sub is_tld {
    my $val = shift;

    my $retval = 0;
    # get the list of tlds
    my @tlds = tlds();
    # now chop off the dc= part
    my (undef, $dn) = split('=', $val);
    # finally test and return bool
    foreach my $tld (@tlds) {
        if ($tld =~ /$dn/) {
            $retval = 1;
            last;
        } else {
            $retval = 0;
        }
    }
    return $retval;
}

my sub drop_tld {
    my $rdn = shift;

    my $domain = '';
    # split our rdn on comma boundary
    my @dc = split(',', $rdn);
    # now reconstruct ONLY the non tld portion
    foreach my $segment (@dc) {
        next if (is_tld($segment));
        if (@dc == 2) {
            $domain = "$segment";
        } else {
            $domain = "$domain,$segment";
        }
    }

    return $domain;
}

my sub base_ldif {
    my $rdn = shift;

    # we don't handle multivalued RDNs here; they're unlikely
    # in a base DN.
    my $domain = drop_tld($rdn);
    my %classmap = get_classmap();
    my ($type, $value) = split('=', $domain);
    print STDOUT "dn: $rdn\n";
    print STDOUT "$type: $value\n";
    print STDOUT "objectClass: top\n";
    print STDOUT "objectClass: $classmap{$type}\n\n";
}

our sub main {
    my $program = basename($0);
    my $basedn = getsuffix($program);
    my %naming_context = get_nc();

    if (exists($ARGV[0])) {
        if ("$ARGV[0]" ne '-n') {
            base_ldif($basedn);
        }
    } else {
        base_ldif($basedn);
    }
    gen_namingcontexts($basedn, %naming_context);
}

main();
