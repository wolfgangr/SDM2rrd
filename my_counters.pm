#!/usr/bin/perl
#

use warnings;
use strict;
use Data::Dumper  qw(Dumper);

our $Debug ;
require ('./my_debugs.pl');


our @SDM_regs =();    		# resembling the raw data for whatever use
our %SDM_reg_by_tag =();  	# for human readable direct access
our %SDM_selectors =();		# indexed by selector / number => tag
include ('./extract-SDM-def.pl');

my @test = qw ( foo bar tralala );

$Debug=2;

# debug_Dumper (1, \%SDM_selectors , \@test );

1;
exit;
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


