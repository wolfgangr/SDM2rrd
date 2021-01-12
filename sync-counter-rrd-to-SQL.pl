#!/usr/bin/perl
#  things getting more elaborated
#  switching from bash to perl
#  boilerplating from create_tables.pl ensures consistent config


use warnings;
use strict;
use Data::Dumper;

# "%s/%s_%s_%s.rrd"; 
our ( $RRD_dir , $RRD_prefix , $RRD_sprintf );
require ('./rrd_def.pm');


#  import database strucutre - we may run this on console to debug
#  tag tree of  %sql_tables->{counter}->{rrd}->{field}
#
my %sql_tables;
my $sql_tables_dump = `./test-SQL-def.pl 2> /dev/null`;

eval ($sql_tables_dump );
print STDERR $@ ; # eval error message
print STDERR Dumper ( \%sql_tables ) ;




