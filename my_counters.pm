###!/usr/bin/perl
#

use warnings;
use strict;
use Data::Dumper  qw(Dumper);

our $Debug ;
require ('./my_debugs.pl');


# our @SDM_regs =();    		# resembling the raw data for whatever use
# our %SDM_reg_by_tag =();  	# for human readable direct access
# our %SDM_selectors =();		# indexed by selector / number => tag
require ('./extract-SDM-def.pl');


# $subsetx = [ qw ( foo bar xyz ) ] 
# but we may extract them from the central definition selectors

our %Counterlist;

$counterlist{'mains'} = (
	bus => 'MODBUS-infini',
	ID =>  1,
	Label => 'Hausanschluss',
	direction => 1 , 
	selectors => [ $foo,  $bar ] ,
);

$counterlist{'subs1'} = (
        bus => 'tcp-241',
        ID =>  1,
        Label => 'Wohnhaus neu',
        direction => 1,
	selectors => [ ] ,
);

$counterlist{'subs2'} = (
        bus => 'tcp-241',
        ID =>  2,
        Label => 'Wohnhaus alt',
        direction => 1,
        selectors => [ ] ,
);

$counterlist{'subs3'} = (
        bus => 'tcp-241',
        ID =>  3,
        Label => 'Stall + Werkstatt',
        direction => 1,
        selectors => [ ] ,
);

$counterlist{'subs4'} = (
        bus => 'tcp-241',
        ID =>  4,
        Label => 'Kartoffellager',
        direction => 1,
        selectors => [ ] ,
);

$counterlist{'subs5'} = (
        bus => 'tcp-241',
        ID =>  5,
        Label => 'Heizung',
        direction => 1,
        selectors => [ ] ,
);

$counterlist{'subs6'} = (
        bus => 'tcp-241',
        ID =>  6,
        Label => 'Infini-LTO',
        direction => -1,
        selectors => [ ] ,
);





# my @test = qw ( foo bar tralala );

# $Debug=2;

# debug_Dumper (1, \%SDM_selectors , \@test );

1;
# exit;
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


