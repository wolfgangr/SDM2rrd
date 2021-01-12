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

my $csv_sprintf = $RRD_sprintf ;
$csv_sprintf =~ s/\.rrd$/.csv/ ;



#  import database strucutre - we may run this on console to debug
#  tag tree of  %sql_tables->{counter}->{rrd}->{field}
#
my %sql_tables;
my $sql_tables_dump = `./test-SQL-def.pl 2> /dev/null`;


eval ($sql_tables_dump );
print STDERR $@ ; # eval error message
print STDERR Data::Dumper->Dump ( [ \%sql_tables ] , [ qw (  *sql_tables  ) ]  ) ;


# try to undestand shell style config
my $secret_pwd = `cat secret.pwd`;
print STDERR $secret_pwd ;

# crude shell variable syntax parser
my %credentials;
for ( split '\n' , $secret_pwd ) {
	next if /^#/ ; # skip comment lines
	my ($tag, $val) = split '=' , $_, 2;
	$val =~ s/"?([^"]*)?"/$1/ ;  # strip quotes
	$credentials{ $tag } = $val ;
}

print STDERR  Data::Dumper->Dump ( [ \%credentials ] , [ qw( *credentials  ) ]   );


# for each rrd
# rrdfile = ...
# tmpfile = ....
# ./rrd2csv.pl $RRDFILE $CF -r 300 -x\; -M -t -f $TEMPFILE

# sprintf template, vars:  
# 	$rrd_file, CF aka 'AVERAGE', $starttime, $csv_file
# my $tpl_rrd2csv = './rrd2csv.pl %s %s  -eN -s%s -r 300 -a -x\; -M -t -f %s'; 

#
#   	mysqlimport -h $HOST -u $USER -p$PASSWD  --local \
#		--ignore --force \
#		--ignore-lines=1 --fields-terminated-by=';' \
#		$DB $TEMPFILE
#

my  $HOST = $credentials{ HOST } or die " no HOST found in secret.pwd";
my  $USER = $credentials{ USER } or die " no USER found in secret.pwd";
my  $PASSWD = $credentials{ PASSWD  } or die " no PASSWD found in secret.pwd";
my  $DB = $credentials{ DB  } or die " no DB found in secret.pwd";




# my $tpl_mysqlimport = <<"EOF_MYSQLIMPORT";
# mysqlimport -h $HOST -u $USER -p$PASSWD  --local 
#     --ignore --force --ignore-lines=1 --fields-terminated-by=';' 
#      $DB %s
# 
# EOF_MYSQLIMPORT


my $tpl_mysqlimport = "mysqlimport -h $HOST -u $USER -p$PASSWD ";
$tpl_mysqlimport .= "--local --ignore --force --ignore-lines=1 --fields-terminated-by=';' ";
$tpl_mysqlimport .= " $DB %s ";


my $tmpdir = $credentials{ TMPDIR } or die " no temp dir found in secret.pwd";
my $CF = $credentials{ CF } or die " no temp dir found in secret.pwd";
my $start = $credentials{ START } or die " no start dir found in secret.pwd";

my $tpl_rrd2csv = "./rrd2csv.pl %s $CF  -eN -s$start -r 300 -a -x\\; -M -t -f %s";


# my $csv_sprintf = $RRD_sprintf ;
# $csv_sprintf =~ s/\.rrd$/.csv/ ;

for my $counter_tag ( sort keys %sql_tables ) {
	my $table_list_p = $sql_tables{ $counter_tag } or next ;
	for my $table_tag ( sort keys %$table_list_p ) {

		# my $tablename = sprintf "%s_%s_%s", $RRD_prefix , $counter_tag, $table_tag ;
		my $rrd_file = sprintf $RRD_sprintf,  $RRD_dir , $RRD_prefix , $counter_tag, $table_tag ;
		my $csv_file = sprintf $csv_sprintf,  $tmpdir  , $RRD_prefix , $counter_tag, $table_tag ;
		printf STDERR "processing SQL-update: %s -> %s\n" , $rrd_file, $csv_file ;

		my $cmd_rrd2scv = sprintf $tpl_rrd2csv, $rrd_file,  $csv_file ;
		print  "\t",  $cmd_rrd2scv , "\n"; 
	       system ($cmd_rrd2scv);

		my $cmd_mysqlimport = sprintf $tpl_mysqlimport, $csv_file ;
	       print  "\t",  $cmd_mysqlimport , "\n";
	       system ($cmd_mysqlimport);
	       die "========= DEBUG ==============";
	}
}

