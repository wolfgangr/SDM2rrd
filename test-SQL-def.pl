#!/usr/bin/perl
#
# prints a hash definition of database structure to STDOUT
# hope this can be loaded by eval `$0` into other routines
# extensive debug goes to STDERR (not configurable) 


use warnings;
use strict;
use Data::Dumper  qw(Dumper);
# use Data::Dumper::Simple :

our $Debug = 3;


require ('./my_debugs.pl');

our $sdm_def_file;
our (@SDM_regs , %SDM_reg_by_tag , %SDM_selectors);
require ('./extract-SDM-def.pm');

our %Counterlist;
our @all_selectors;
require ('./my_counters.pm');

our %RRD_definitions ;
our %SQL_export;
require ('./rrd_def.pm');

#debug_dumper (3, 
# print Data::Dumper->Dump (
# 	[ \@SDM_regs , \%SDM_reg_by_tag , \%SDM_selectors , \@all_selectors , \%Counterlist  ] ,
# 	[ qw(*SDM_regs  *SDM_reg_by_tag   *SDM_selectors  *all_selectors       *Counterlist ) ]  );

# print Data::Dumper->Dump ( [ \%RRD_definitions ]  , [ qw( *RRD_definitions) ]  );

print STDERR Data::Dumper->Dump ( [ \%SQL_export  ]  , [ qw(  *SQL_export ) ]  );

print STDERR " ===== all available rrd defs : " , join (' ' , keys %RRD_definitions ), " =====\n";
print STDERR " subset selection for SQL export: \n";


my %sql_columns;
foreach my $rrd (keys %RRD_definitions ) {


	my $sxp = $SQL_export{ $rrd };
	next unless $sxp;

	my $fields = [] ;
	if ( $sxp->{ any } ) {
		my $rrd_hp = $RRD_definitions{$rrd} ;
		$fields = $rrd_hp->{fields};
	}
	if ( my $sfp = $sxp->{ fields } ) {
		$fields = $sfp ;
	}
	# print Dumper  ( $fields, $rrd_hp);
	print STDERR $rrd, ": ";
	print STDERR join (', ' , @$fields ),  "\n";
	$sql_columns{ $rrd } = \@$fields ;
}

print STDERR Data::Dumper->Dump ( [ \%sql_columns  ]  , [ qw(  *sql_columns ) ]  );
print STDERR Data::Dumper->Dump ( [  \%Counterlist  ]  , [ qw(   *Counterlist ) ]  );

my %sql_tables ;

foreach my $c_tag ( sort keys %Counterlist ) {
	my $c_ptr = $Counterlist{ $c_tag } ;
	my $c_rrds = $c_ptr->{ rrds } ;
	foreach my $c_rrd_tag ( @{$c_rrds} ) {

		# if the tag at question defined in the counter is configured for SQL export...
		if ( my $c_sql_c_p = $sql_columns{ $c_rrd_tag } ) {
			$sql_tables{ $c_tag }->{ $c_rrd_tag   }  =  $c_sql_c_p  ; # should remain constant, so we can add this as a ref
		}
	}

}

print STDERR Data::Dumper->Dump ( [  \%sql_tables  ]  , [ qw( *sql_tables    ) ]  );


# debug_dumper (3, \%Counterlist);

# my @all_selectors = map { $_ 
#    keys 
# } sort keys %SDM_selectors ;




# debug_dumper (3, \@all_selectors );

exit;

