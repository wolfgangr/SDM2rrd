#!/usr/bin/perl
# crude hack to create tables
# print debug to SDTERR
# working output to file

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

# database chunks - basically copy over from infini

my $outer_head = <<"EOF_OHEAD";
/*!40101 SET character_set_client = utf8 */;
EOF_OHEAD

my $tabdef_head = <<"EOF_TDHEAD";
DROP TABLE IF EXISTS `%s`;
CREATE TABLE `%s` (
  `time` datetime NOT NULL,
EOF_TDHEAD

# hope that a generic float type meets best , no need for per col config
my $tabdef_row = <<"EOF_TDROW" ;
  `%s` float DEFAULT NULL,
EOF_TDROW
  
my $tabdef_tail = <<"EOF_TDTAIL";
  `update_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' ON UPDATE current_timestamp(),
  PRIMARY KEY (`time`)
) ENGINE=MyISAM DEFAULT CHARSET=ascii ;

EOF_TDTAIL


print STDERR "========== start parsing data tree \n ==========";

# prelude
print $outer_head;

# cycle over tables

my $db_sprintf = $RRD_sprintf ;
# $db_sprintf =~ s/\.rrd$/.sql/ ;





for my $counter_tag ( sort keys %sql_tables ) {
	my $table_list_p = $sql_tables{ $counter_tag } or next ;
	for my $table_tag ( sort keys %$table_list_p ) {

		my $tablename = sprintf "%s_%s_%s", $RRD_prefix , $counter_tag, $table_tag ;

		# output table heads
		printf $tabdef_head, $tablename, $tablename ;

		# cycle over rows
		my $col_list_p = $$table_list_p{ $table_tag } or next ;
		for my $trow (@$col_list_p ) {
			printf $tabdef_row, $trow;
		}
	print $tabdef_tail;

	}
}
