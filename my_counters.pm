###!/usr/bin/perl
#

use warnings;
use strict;
use Data::Dumper  qw(Dumper);

our $Debug ;
require ('./my_debugs.pl');


our %SDM_selectors ;		# indexed by selector / number => tag
require ('./extract-SDM-def.pm');



our @all_selectors;

foreach my $sel ( sort keys %SDM_selectors ) {
  my %registers = %{$SDM_selectors{ $sel }} ;

  my @sorted_tags = 
  	map { $registers{ $_ } } 
	sort {$a <=> $b} keys %registers ;

  push @all_selectors, [ @sorted_tags ] ;
}

# here we collect the counter properies
# defaults are completed at the end
our %Counterlist;

$Counterlist{'mains'} = { 
	bus => 'MODBUS-infini',
	ID =>  1,
	Label => 'Hausanschluss',
        # direction => 1,
        # selectors => [ ] ,
	rrds => [ qw( totalP )],
};

$Counterlist{'subs1'} = {
        bus => 'tcp-241',
        ID =>  1,
        Label => 'Wohnhaus neu',
};

$Counterlist{'subs2'} = {
        bus => 'tcp-241',
        ID =>  2,
        Label => 'Wohnhaus alt',
};

$Counterlist{'subs3'} = {
        bus => 'tcp-241',
        ID =>  3,
        Label => 'Stall + Werkstatt',
};

$Counterlist{'subs4'} = {
        bus => 'tcp-241',
        ID =>  4,
        Label => 'Kartoffellager',
};

$Counterlist{'subs5'} = {
        bus => 'tcp-241',
        ID =>  5,
        Label => 'Heizung',
};

$Counterlist{'subs6'} = {
        bus => 'tcp-241',
        ID =>  6,
        Label => 'Infini-LTO',
        direction => -1,
	selectors => [ [ 'Ptot' ]  ] ,
	rrds	=> [ qw( totalP E_bidir elbasics elquality )],
};


# fill defaults

# elbasics E_unidir totalP elquality E_bidir
my $default_rrds = [ qw( totalP E_unidir elbasics elquality )] ;

foreach my $counter ( values %Counterlist) {

	unless ( defined $counter->{direction} ) { 
		$counter->{direction} = 1 };

	unless ( defined $counter->{selectors} ) { 
		$counter->{selectors} = \@all_selectors };

	unless ( defined $counter->{rrds} ) {
		$counter->{rrds} = $default_rrds } ;
}


# my @test = qw ( foo bar tralala );

# $Debug=2;

# debug_Dumper (1, \%SDM_selectors , \@test );

1;
# exit;
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


