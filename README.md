# MigrationTools
Migrate a machine's NSS configuration to LDAP

==================================================================
                           MigrationTools
==================================================================

THIS SOFTWARE IS PROVIDED "AS IS" WITHOUT EXPRESS OR IMPLIED
WARRANTY AND WITHOUT SUPPORT.

These tools are freely redistributable according to the license
included with the source files. They may be bundled with LDAP/NIS
migration products. See RFC 2307 for more information.

You need perl to run these.

Edit migrate_common.ph and change the following site-specific
variables to reflect your installation:

$DEFAULT_MAIL_DOMAIN 
$DEFAULT_BASE

Then run the tools on each of your /etc database files, eg.
to migrate protocols you might do:

./migrate_protocols.pl /etc/protocols protocols.ldif

where the first argument is the input file and the last argument
is the output file. You then can concatenate all your output files
together and load that into your LDAP database with an online or
offline import tool (such as ldapadd and slapadd, respectively).

The following table will tell you which migration shell script
to use:

Script                          Existing nameservice    LDAP online
===================================================================
migrate_all_online.sh           /etc flat files         YES
migrate_all_offline.sh          /etc flat files         NO
migrate_all_netinfo_online.sh   NetInfo                 YES
migrate_all_netinfo_offline.sh  NetInfo                 NO
migrate_all_nis_online.sh       Sun NIS/YP              YES
migrate_all_nis_offline.sh      Sun NIS/YP              NO
migrate_all_nisplus_online.sh   Sun NIS+                YES
migrate_all_nisplus_offline.sh  Sun NIS+                NO

(The online scripts use ldapadd; the offline scripts use ldif2ldbm.)

MigrationTools Copyright (C) 1996-2001 Luke Howard. All rights reserved. 

You may contact the maintainers at support@padl.com.

