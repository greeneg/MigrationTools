#!/usr/bin/perl
#
# $Id: migrate_passwd.pl,v 1.17 2005/03/05 03:15:55 lukeh Exp $
#
# Copyright (c) 1997-2003 Luke Howard.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#	notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#	notice, this list of conditions and the following disclaimer in the
#	documentation and/or other materials provided with the distribution.
# 3. All advertising materials mentioning features or use of this software
#	must display the following acknowledgement:
#		This product includes software developed by Luke Howard.
# 4. The name of the other may not be used to endorse or promote products
#	derived from this software without specific prior written permission.
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
# Password migration tool. Migrates /etc/shadow as well, if it exists.
#
# Thanks to Peter Jacob Slot <peter@vision.auk.dk>.
#

use strict;
use warnings;

use feature ":5.24";

use File::Basename;

use lib './lib';
use MigrationTools::Common;

my sub dump_shadow_attributes {
	my ($fh, $user, $pwd, $lastchg, $min, $max, $warn, $inactive, $expire, $flag) = @_;

	print $fh "objectClass: shadowAccount\n";
	if ($pwd) {
		print $fh "userPassword: {crypt}$pwd\n";
	}
	if ($lastchg ne "") {
		print $fh "shadowLastChange: $lastchg\n";
	}
	if ($min) {
		print $fh "shadowMin: $min\n";
	}
	if ($max) {
		print $fh "shadowMax: $max\n";
	}
	if ($warn) {
		print $fh "shadowWarning: $warn\n";
	}
	if ($inactive) {
		print $fh "shadowInactive: $inactive\n";
	}
	if ($expire) {
		print $fh "shadowExpire: $expire\n";
	}
	if ($flag) {
		print $fh "shadowFlag: $flag\n";
	}
}

my sub dump_user {
    my ($fh, $user, $pwd, $uid, $gid, $gecos, $homedir, $shell, $basedn, %shadow_users) = @_;
    my ($name, $office, $wphone, $hphone)=split(/,/, $gecos); # hack on older UNIXs
    my ($sn, $givenname, $cn, @tmp);

    if ($name) {
        $cn = $name;
    } else {
        $cn = $user;
    }

	@tmp = split(/\s+/, $cn);
	$sn = $tmp[$#tmp];
	pop(@tmp);
	$givenname = join(' ', @tmp);
	
	print $fh "dn: uid=$user,$basedn,$DEFAULT_BASE\n";
	print $fh "uid: $user\n";
	print $fh "cn: $cn\n";

	if ($EXTENDED_SCHEMA) {
		if ($wphone) {
			print $fh "telephoneNumber: $wphone\n";
		}
		if ($office) {
			print $fh "roomNumber: $office\n";
		}
		if ($hphone) {
			print $fh "homePhone: $hphone\n";
		}
		if ($givenname) {
			print $fh "givenName: $givenname\n";
		}
		print $fh "sn: $sn\n";
		if ($DEFAULT_MAIL_DOMAIN) {
			print $fh "mail: $user\@$DEFAULT_MAIL_DOMAIN\n";
		}
		if ($DEFAULT_MAIL_HOST) {
			print $fh "mailRoutingAddress: $user\@$DEFAULT_MAIL_HOST\n";
			print $fh "mailHost: $DEFAULT_MAIL_HOST\n";
			print $fh "objectClass: inetLocalMailRecipient\n";
		}
		print $fh "objectClass: person\n";
		print $fh "objectClass: organizationalPerson\n";
		print $fh "objectClass: inetOrgPerson\n";
	} else {
		print $fh "objectClass: account\n";
	}

	print $fh "objectClass: posixAccount\n";
	print $fh "objectClass: top\n";

    if ($uid == 0 || $uid >= 1000) {
	    if ($DEFAULT_REALM) {
		    print $fh "objectClass: kerberosSecurityObject\n";
	    }

        # only do this if not in a krb5 realm
        unless (defined $DEFAULT_REALM) {
            if ($shadow_users{$user} ne "") {
                dump_shadow_attributes($fh, split(/:/, $shadow_users{$user}));
            } else {
                print $fh "userPassword: {crypt}$pwd\n";
            }
        }

        if ($DEFAULT_REALM) {
            print $fh "krbName: $user\@$DEFAULT_REALM\n";
        }
    }

	if ($shell) {
		print $fh "loginShell: $shell\n";
	}

	if ($uid ne "") {
		print $fh "uidNumber: $uid\n";
	} else {
		print $fh "uidNumber:\n";
	}

	if ($gid ne "") {
		print $fh "gidNumber: $gid\n";
	} else {
		print $fh "gidNumber:\n";
	}

	if ($homedir) {
		print $fh "homeDirectory: $homedir\n";
	} else {
		print $fh "homeDirectory:\n";
	}

	if ($gecos) {
		print $fh "gecos: $gecos\n";
	}

	print $fh "\n";
}

my sub read_shadow_file {
	open(my $shadow_fh, "/etc/shadow") || return;

    my %shadow_users;
	foreach my $line (<$shadow_fh>) {
		chomp $line;
		my ($shadow_user, undef, undef, undef, undef, undef, undef, undef, undef ) = split(/:/, $line);
		$shadow_users{$shadow_user} = $line;
	}
	close $shadow_fh;

    return %shadow_users;
}

my sub process_non_ascii_chars {
    my $line = shift;

    $line =~ s/Ä/Ae/g;
    $line =~ s/Ë/Ee/g;
    $line =~ s/Ï/Ie/g;
    $line =~ s/Ö/Oe/g;
    $line =~ s/Ü/Ue/g;

    $line =~ s/ä/ae/g;
    $line =~ s/ë/ee/g;
    $line =~ s/ï/ie/g;
    $line =~ s/ö/oe/g;
    $line =~ s/ü/ue/g;
    $line =~ s/ÿ/ye/g;
    $line =~ s/ß/ss/g;
    $line =~ s/é/e/g;

    $line =~ s/Æ/Ae/g;
    $line =~ s/æ/ae/g;
    $line =~ s/Ø/Oe/g;
    $line =~ s/ø/oe/g;
    $line =~ s/Å/Ae/g;
    $line =~ s/å/ae/g;

    return $line;
}

our sub main {
    my $program = basename($0);
    my $basedn = getsuffix($program);

    my ($in, $out) = parse_args(@ARGV);
    my %shadow_users = read_shadow_file();
    my ($use_stdout, $in_fh, $out_fh) = open_files($in, $out);

    foreach my $line (<$in_fh>) {
        chomp $line;
        next if ($line =~ /^\s*$/) || ($line =~ /^#/) || ($line =~ /^\+/);

        my $line = process_non_ascii_chars($line);
        my ($user, $pwd, $uid, $gid, $gecos, $homedir, $shell) = split(/:/, $line);
	
        if ($use_stdout) {
            dump_user(\*STDOUT, $user, $pwd, $uid, $gid, $gecos, $homedir, $shell, $basedn, %shadow_users);
        } else {
            dump_user($out_fh, $user, $pwd, $uid, $gid, $gecos, $homedir, $shell, $basedn, %shadow_users);
        }
    }

    close $in_fh;
    if (defined($out_fh)) {
        close $out_fh;
    }
}

main();
