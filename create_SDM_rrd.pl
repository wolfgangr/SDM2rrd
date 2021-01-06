#!/usr/bin/perl
# create rrds for SDM data logging matching our definitions around here

our $usage = <<"EOF_USAGE";
usage: $0 [ options ]
  -d		dryrun
  -t		touch file only
  -f		force_overwrite
  -a		ask before each creation

  -d dir 	alternateve rrd dir
  -p prefix	alternative rrd prefix

  -c cnt_tag	counter matching tag only
  -r rrd_tag	rrd matching tag only
  -l		list counters and rrds

  -v level	set verbosity level
  -h		print this message
  
EOF_USAGE

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
use warnings;
use strict;

use Getopt::Std;
use  RRDs;
use DateTime;
use Data::Dumper  ;


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

our $Debug = 3;
require ('./my_debugs.pl');



my $retval = getopts('dtfad:p:c:r:lv:h');
die "$usage" unless ($retval) ;
die "$usage" if my $opt_h  ;

our $sdm_def_file;
our (@SDM_regs , %SDM_reg_by_tag , %SDM_selectors);
require ('./extract-SDM-def.pm');

our %Counterlist;
our @all_selectors;
require ('./my_counters.pm');


our ( $RRD_dir , $RRD_prefix , $RRD_sprintf );
our %RRD_definitions ;
require ('./rrd_def.pm');

print Data::Dumper->Dump (
	[ \@SDM_regs , \%SDM_reg_by_tag , \%SDM_selectors , \@all_selectors , \%Counterlist  ] ,
	[ qw(*SDM_regs  *SDM_reg_by_tag   *SDM_selectors  *all_selectors       *Counterlist ) ]  );

print Data::Dumper->Dump ( [ \%RRD_definitions ]  , [ qw(%RRD_definitions) ]  );



