#!/usr/bin/perl
#


# precook queries for infini-SDM-sniffer / multi-master

# just extract the queries I want from the definitions
# boilerplate: ./test-counter-def.pl


use warnings;
use strict;
use Data::Dumper  qw(Dumper);
# use Data::Dumper::Simple :

our $Debug = 3;

my $counter_tag = 'mains_d';

#==================

require ('./my_debugs.pl');

our $sdm_def_file;
our (@SDM_regs , %SDM_reg_by_tag , %SDM_selectors);
require ('./extract-SDM-def.pm');

our %Counterlist;
our @all_selectors;
require ('./my_counters.pm');

if (0) {
  debug_print ( 3,  Data::Dumper->Dump (
	[ \@SDM_regs , \%SDM_reg_by_tag , \%SDM_selectors , \@all_selectors , \%Counterlist  ] ,
	[ qw(*SDM_regs  *SDM_reg_by_tag   *SDM_selectors  *all_selectors       *Counterlist ) ]  )
  );
}


my $counter_ptr = $Counterlist{ $counter_tag };
my $device_ID = $counter_ptr->{ ID } ;
my $device_bus = $counter_ptr->{ bus } ;

debug_printf ( 3, "my \$counter_ptr %s \n", Dumper ( $counter_ptr) );
debug_printf ( 3, "details: ID=%d, bus=%s \n",  $device_ID, $device_bus );


