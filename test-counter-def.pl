#!/usr/bin/perl
#

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
print Data::Dumper->Dump (
	[ \@SDM_regs , \%SDM_reg_by_tag , \%SDM_selectors , \@all_selectors , \%Counterlist  ] ,
	[ qw(*SDM_regs  *SDM_reg_by_tag   *SDM_selectors  *all_selectors       *Counterlist ) ]  );

print Data::Dumper->Dump ( [ \%RRD_definitions ]  , [ qw( *RRD_definitions) ]  );

print Data::Dumper->Dump ( [ \%SQL_export  ]  , [ qw(  *SQL_export ) ]  );

print " ===== rrd defs : " , join (' ' , keys %RRD_definitions ), " =====\n";

foreach my $rrd (keys %RRD_definitions ) {
	my $rrd_hp = $RRD_definitions{$rrd} ;
	my $fields = $RRD_definitions{$rrd}->{fields};
	# print Dumper  ( $fields, $rrd_hp);
	print $rrd, "\n";
	print join (' ' , @$fields ),  "\n";
}

# debug_dumper (3, \%Counterlist);

# my @all_selectors = map { $_ 
#    keys 
# } sort keys %SDM_selectors ;




# debug_dumper (3, \@all_selectors );

exit;

