#!/usr/bin/perl
#  things getting more elaborated
#  switching from bash to perl
#  boilerplating from create_tables.pl ensures consistent config


use warnings;
use strict;
use Data::Dumper;



# "%s/%s_%s_%s.rrd"; 
our ( $RRD_dir , $RRD_prefix , $RRD_sprintf );
our %SQL_export ;
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
print STDERR Data::Dumper->Dump ( [ \%sql_tables , \%SQL_export] , [ qw (  *sql_tables *SQL_export ) ]  ) ;


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

# die "------- d e b u g -----";

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
$tpl_mysqlimport .= " %s $DB %s ";


my $tmpdir = $credentials{ TMPDIR } or die " no temp dir found in secret.pwd";
# my $CF = $credentials{ CF } or die " no temp dir found in secret.pwd";
my $start = $credentials{ START } or die " no start dir found in secret.pwd";

my $tpl_rrd2csv = "./rrd2csv.pl %s %s  -eN -s$start -r 300 -a -x\\; -M -t -f %s";
my $tpl_rrd_cols = "rrdtool lastupdate %s | head -n1 ";

# my $csv_sprintf = $RRD_sprintf ;
# $csv_sprintf =~ s/\.rrd$/.csv/ ;

for my $counter_tag ( sort keys %sql_tables ) {
	my $table_list_p = $sql_tables{ $counter_tag } or next ;
	for my $table_tag ( sort keys %$table_list_p ) {
		
		my $cf = $SQL_export{ $table_tag }->{ CF } or die "CF not configured for $table_tag " ; 

		my $col_list_p = $$table_list_p{ $table_tag } or die "column list not configured for $table_tag " ;
		my @db_columns = @$col_list_p ;
		print STDERR "  want cols: ", join ( ', ', @db_columns) , "\n" ;

		# my $cmd_rrd_h = sprintf $tpl_rrd_cols, 
		# my $rrd_header = 

		# my $tablename = sprintf "%s_%s_%s", $RRD_prefix , $counter_tag, $table_tag ;
		my $rrd_file = sprintf $RRD_sprintf,  $RRD_dir , $RRD_prefix , $counter_tag, $table_tag ;
		my $csv_file = sprintf $csv_sprintf,  $tmpdir  , $RRD_prefix , $counter_tag, $table_tag ;

		printf STDERR "... building column index for %s .... \n" , $rrd_file;
		my $cmd_rrd_h = sprintf $tpl_rrd_cols, $rrd_file  ;
		print  STDERR "\t", $cmd_rrd_h, , "\n";

		my $rrd_header = `$cmd_rrd_h`;
		my @rrd_columns = split (  ' '    ,   $rrd_header  ) ;
		unless ( scalar @rrd_columns ) { die "cannot retrieve column tags from $rrd_file " ; }
		print STDERR "  have cols: ", join ( ', ', @rrd_columns) , "\n" ;

		# build reverse column index
		my %idx_c ;
		for my $i (0 .. $#rrd_columns)  { $idx_c{ $rrd_columns[ $i ] } = $i  ; }
			
		print STDERR Data::Dumper->Dump ( [ \%idx_c ] ,  [ qw( *idx_c ) ] ) ;

		# now build a header and a col selection phrase

		# | cut -d\; -f1,2,3,4  first column is 1, and for datetime
		my $cmd_cut = ' | cut -d\; -f1';

		# TODO: mysql import header
		my $sql_cols = ' --columns=`time`';

		for my $c ( @db_columns ) {
			$cmd_cut .= ',' . ( $idx_c{ $c } + 2 )  ;
			$sql_cols .= ', `' . $c . '`' ;
		}
		printf STDERR "cmd_cut= >%s< \n", $cmd_cut ;

	# ~~~~~~~~~~~~~ SQL: ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		printf STDERR "processing SQL-update: %s -> %s\n" , $rrd_file, $csv_file ;
		

		my $cmd_rrd2scv = sprintf $tpl_rrd2csv, $rrd_file, $cf , $csv_file ;
		$cmd_rrd2scv .= $cmd_cut ;
		print  STDERR "\t",  $cmd_rrd2scv , "\n"; 
		# system ($cmd_rrd2scv);

		my $cmd_mysqlimport = sprintf $tpl_mysqlimport, $sql_cols, $csv_file ;
	       print  STDERR "\t",  $cmd_mysqlimport , "\n";
	       # system ($cmd_mysqlimport);
	       die "========= DEBUG ==============";
	       # TODO : for selected subfields, we better should consider
	       # at the moment I think it simply takes the first and drops the tail
	       # which works nice by accident at current config
	}
}

