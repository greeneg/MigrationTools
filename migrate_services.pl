#!/usr/bin/perl
#
# $Id: migrate_services.pl,v 1.8 2003/04/15 03:09:34 lukeh Exp $
#
# Copyright (c) 1997-2003 Luke Howard.
# All rights reserved.
#
# Heavily mangled by Bob Apthorpe sometime in June, 2002.
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
# services migration tool
#
#

use strict;
use warnings;

use feature ":5.24";

use File::Basename;

use lib './lib';
use MigrationTools::Common;

##### Subroutines #####

sub parse_services {
    my $in_fh = shift;

	# A note about %services:
	# %services is a reference to a hash of service information. The structure
    # is:
	# 
	# $services{$port}{$servicename}{$proto}{'cn'} = $canonicalservicename;
	# $services{$port}{$servicename}{$proto}{'aliases'}{$alias} = 1;
	#
	# so @ports = keys(%{$Rh_services});
	# @services_on_a_port = keys(%services);
	#
	# Aliases are stored in a hash to keep them normalized, though it's sort of
    # a waste since the aliases are normalized again when protocols are
    # combined while creating records. It's not clear you save any space by
    # storing aliases as a list (allowing multiple identical names to be stored
    # until being normalized away at the end) vs storing them as a hash
    # (storing useless hash values to keep the aliases normalized as keys.)
    # It's also not clear this is even worth worrying about...
    my %services = ();
    my %portmap = ();

	my %svcmap = ();
	my %protocols_found = ();

	foreach my $card (<$in_fh>) {
		next if ($card =~ m/^\s*#/o || $card eq "\n");
        chomp $card;
		$card =~ s/#.*//o;

		my ($service, $portproto, @aliases) = split(m/\s+/o, $card);
		my ($rawport, $proto) = split(m#[/,]#o, $portproto);

		# Find services specifying a port range (e.g. X11.)
		my ($loport, $hiport) = '';
		if ($rawport =~ m#(\d+)-(\d+)#o) {
			$loport = $1;
			$hiport = $2;
		} else {
			$loport = int($rawport);
			$hiport = $loport;
		}
	
		$hiport = $loport if (!defined($hiport) || ($hiport < $loport));

		# Track the number of unique ports used by a service.
		foreach my $p ($loport .. $hiport) {
			$portmap{$service}{$proto}{$p} = 1;
		}

        foreach my $port ($loport .. $hiport) {
            unless (exists($services{$port}{$service}{$proto}{'cn'})) {
                # We've never seen this port/protocol pair before so we take
                # the first occurence of the name as the canonical one, in case
                # we see repeated listings later (see below)
                $svcmap{$port}{$proto} = $service;
                $services{$port}{$service}{$proto}{'cn'} = $service;
                foreach my $alias ($service, @aliases) {
                    $services{$port}{$service}{$proto}{'aliases'}{$alias} = 1;
                }
            } else {
                # We've seen this port/protocol pair before so we'll add the
                # service name and any aliases as aliases in the original
                # (canonical) record.
                my $canonical_svc = $svcmap{$port}{$proto};
                foreach my $alias ($service, @aliases) {
                    $services{$port}{$canonical_svc}{$proto}{'aliases'}{$alias} = 1;
                }
            }
        }
    }

	return \%services, \%portmap;
}

sub build_service_records {
	my $services = shift;
	my $portmap = shift;
    my $basedn = shift;

    my %services = %{$services};
    my @records;

    foreach my $port (sort {$a <=> $b} (keys %services)) {
        foreach my $service (keys %{$services{$port}}) {
            my @protocols;
            foreach my $protocol (keys %{$services{$port}->{$service}}) {
                push @protocols, $protocol;
            }
            my %tmpaliases = ();

            # Note on the suffix:
            # If a service name applies to a range of ports, add a suffix to
            # the cn and the aliases to ensure unique dn's for each service.
            # The NIS schema that defines ipService (1.3.6.1.1.1.2.3) and 
            # ipServicePort (1.3.6.1.1.1.1.15) only allows a single port to be
            # associated with a service name so we have to mangle the cn to
			# differentiate the dn's for each port. This is ugly; the
            # alternative is to change the schema or the format of the services
            # file. "Irresistable Force, meet Immovable Object..."
            my $suffix = '';
            foreach my $proto (@protocols) {
                # Only add suffix if it's absolutely necessary
                if (scalar @protocols > 1) {
                    $suffix = "+ipServicePort=" . escape_metacharacters($port);
                }

                # Normalize aliases across protocols.
                foreach my $alias (keys %{$services{$port}->{$service}->{$proto}->{'aliases'}}) {
                    $tmpaliases{$alias} = 1;
                }
            }

            my @aliases = keys %tmpaliases;
            # Finally we build LDIF records for services.
            push(@records, "dn: cn=" . escape_metacharacters($service)
				. $suffix
				. ",$basedn,$DEFAULT_BASE\n"
				. "objectClass: ipService\n"
				. "objectClass: top\n"
				. "ipServicePort: $port\n"
				. join('', map { "ipServiceProtocol: $_\n" } (@protocols))
				. join('', map { "cn: $_\n" } (@aliases))
				. "\n"
            );
		}
	}

	return @records;
}

our sub main {
    my $program = basename($0);
    my $basedn = getsuffix($program);

    my ($in, $out) = parse_args(@ARGV);
    my ($use_stdout, $in_fh, $out_fh) = open_files($in, $out);

    my ($services, $portmap) = parse_services($in_fh);

    my @records = build_service_records($services, $portmap, $basedn);
    foreach my $record (@records) {
        if ($use_stdout) {
	        print STDOUT $record;
        } else {
	        print $out_fh $record;
        }
    }

    close $in_fh;
    if (defined($out_fh)) {
        close $out_fh;
    }
}

main();
