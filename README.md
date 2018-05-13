# MigrationTools

Migrate a machine's NSS configuration to LDAP

This code is forked from the MigrationTools sources found [here](https://www.padl.com/OSS/MigrationTools.html).

These tools have been rewritten for modern Perl conventions. Older technologies
that cannot be tested against have been removed, specifically NIS+ and NetInfo.

Additionally, offline support has been removed, as ldif2ldbm is no longer part
of the OpenLDAP releases.

---

<b>THIS SOFTWARE IS PROVIDED "AS IS" WITHOUT EXPRESS OR IMPLIED WARRANTY OR
SUPPORT.</b>

These tools are freely redistributable according to the license included
with the source files. They may be bundled with LDAP/NIS migration products.
See RFC 2307 for more information.

## Requirements

These tools require a UNIX or UNIX-like host to run on, and must have the 
following tools installed to run correctly:

* Perl, version 5.24 or greater
* The following Perl Modules:
  - Net::Domain::TLD
  - File::Basename
  - Getopt::Long
  - Exporter
* OpenLDAP tools

You need perl to run these.

Edit the ini file in the root of the sources change the following 
site-specific variables to reflect your installation:

* mail_domain
* basedn

Then run the tools on each of your /etc database files, eg.
to migrate protocols you might do:

```bash
./migrate_protocols.pl /etc/protocols protocols.ldif
```

where the first argument is the input file and the last argument
is the output file. You then can concatenate all your output files
together and load that into your LDAP database with an online or
offline import tool (such as ldapadd and slapadd, respectively).

The following table will tell you which migration shell script
to use:

| Script | Existing nameservice |
| --- | --- |
| migrate_all_online.sh | /etc flat files |
| migrate_all_nis_online.sh | Sun NIS/YP |

The online scripts use ldapadd.

MigrationTools Copyright (C) 1996-2001 Luke Howard. All rights reserved. 
Heavily modified for modern Perl environments by Gary Greene
