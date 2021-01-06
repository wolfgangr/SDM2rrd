###!/usr/bin/perl
#

use warnings;
use strict;
use Data::Dumper  qw(Dumper);

our $Debug ;
require ('./my_debugs.pl');


# our @SDM_regs =();    		# resembling the raw data for whatever use
# our %SDM_reg_by_tag =();  	# for human readable direct access
our %SDM_selectors ;		# indexed by selector / number => tag
require ('./extract-SDM-def.pm');


# $subsetx = [ qw ( foo bar xyz ) ] 
# but we may extract them from the central definition selectors

our @all_selectors;

foreach my $sel ( sort keys %SDM_selectors ) {
  # debug_dumper (3, $sel );

  # die "debug" ;
  my %registers = %{$SDM_selectors{ $sel }} ;

  # debug_dumper (3, \%registers  );
  # die "debug" ;

  my @sorted_tags = map { $registers{ $_ } } sort keys %registers ;
  # debug_dumper (3, \@sorted_tags) ;
  # die "debug" ;

  push @all_selectors, [ @sorted_tags ] ;
}

our %Counterlist;

$Counterlist{'mains'} = { 
	bus => 'MODBUS-infini',
	ID =>  1,
	Label => 'Hausanschluss',
	# direction => 1 , 
	# selectors => [  ] ,
};

$Counterlist{'subs1'} = {
        bus => 'tcp-241',
        ID =>  1,
        Label => 'Wohnhaus neu',
	# direction => 1,
	# selectors => [ ] ,
};

$Counterlist{'subs2'} = {
        bus => 'tcp-241',
        ID =>  2,
        Label => 'Wohnhaus alt',
	# direction => 1,
	# selectors => [ ] ,
};

$Counterlist{'subs3'} = {
        bus => 'tcp-241',
        ID =>  3,
        Label => 'Stall + Werkstatt',
	# direction => 1,
	# selectors => [ ] ,
};

$Counterlist{'subs4'} = {
        bus => 'tcp-241',
        ID =>  4,
        Label => 'Kartoffellager',
	# direction => 1,
	# selectors => [ ] ,
};

$Counterlist{'subs5'} = {
        bus => 'tcp-241',
        ID =>  5,
        Label => 'Heizung',
	# direction => 1,
	# selectors => [ ] ,
};

$Counterlist{'subs6'} = {
        bus => 'tcp-241',
        ID =>  6,
        Label => 'Infini-LTO',
        direction => -1,
	selectors => [ [ 'Ptot' ]  ] ,
};


# fill defaults
foreach my $counter ( values %Counterlist) {
	unless ( defined $counter->{direction} ) { $counter->{direction} = 1 };
	unless ( defined $counter->{selectors} ) { $counter->{selectors} = \@all_selectors };
}


# my @test = qw ( foo bar tralala );

# $Debug=2;

# debug_Dumper (1, \%SDM_selectors , \@test );

1;
# exit;
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


