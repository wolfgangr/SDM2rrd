#!/usr/bin/perl
#

use warnings;
use strict;
use Data::Dumper  qw(Dumper);

our $Debug = 3;
require ('./my_debugs.pl');

our $sdm_def_file;
our ($SDM_regs , $SDM_reg_by_tag , $SDM_selectors);
require ('./extract-SDM-def.pm');

# our $sdm_def_file = "SDM630proto-usage.csv" ;


# two line test code and usage guide
# ($SDM_regs , $SDM_reg_by_tag , $SDM_selectors)   =( read_csv_SDM_def ( $sdm_def_file ));
# debug_dumper ( 3, $SDM_regs, $SDM_reg_by_tag , $SDM_selectors );
debug_dumper (3, $SDM_selectors );

exit;

