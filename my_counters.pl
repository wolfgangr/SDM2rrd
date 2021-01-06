#!/usr/bin/perl
#

use warnings;
use strict;
use Data::Dumper  qw(Dumper);

our $Debug = 5;
require ('./my_debugs.pl');


our @SDM_regs =();    		# resembling the raw data for whatever use
our %SDM_reg_by_tag =();  	# for human readable direct access
our %SDM_selectors =();		# indexed by selector / number => tag
require ('./extract-SDM-def.pl');

debug_Dumper (3, \%SDM_selectors );

1;
exit;
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


