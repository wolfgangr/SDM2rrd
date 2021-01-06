#!/usr/bin/perl
# create rrds for SDM data logging matching our definitions around here

our $usage = <<"EOF_USAGE";
usage: $0 [ options ]
  -D		dryrun
  -t		touch file only
  -f		force_overwrite
  -a		ask before each creation
  -s		create shell creator skripts instead of executing

  -d dir 	alternateve rrd dir
  -p prefix	alternative rrd prefix

  -c cnt_tag	counter matching tag only
  -r rrd_tag	rrd matching tag only
  -l		list counters and rrds

  -v level	set verbosity level
  -q		suppress explaining output
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



my $retval = getopts('Dtfasd:p:c:r:lv:qh');
our ( $opt_D , $opt_t , $opt_f , $opt_a , $opt_s,  $opt_d , $opt_p , 
	$opt_c , $opt_r , $opt_l , $opt_v , $opt_q, $opt_h , ) ; 

die "$usage" unless ($retval) ;
die "$usage" if  $opt_h  ;
$Debug = $opt_v if $opt_v ;

# if 

our $sdm_def_file;
our (@SDM_regs , %SDM_reg_by_tag , %SDM_selectors);
require ('./extract-SDM-def.pm');

our %Counterlist;
our @all_selectors;
require ('./my_counters.pm');


our ( $RRD_dir , $RRD_prefix , $RRD_sprintf );
our %RRD_definitions ;
require ('./rrd_def.pm');

if ($opt_d) { $RRD_dir = $opt_d ; }
if ($opt_p) { $RRD_prefix = $opt_p ; }

my @counters = sort keys %Counterlist;
my @rrddefs  = sort keys %RRD_definitions;

if ($opt_l) {
	print "params expand to rrd file template: ";
	printf ($RRD_sprintf, $RRD_dir, $RRD_prefix , '<counter>', '<rrd-def>');
	print "\n";

	print "  - available counters:  ";
	print join ( ' ', @counters), "\n";
	print "  - available rrd defs:  ";
	print join ( ' ', @rrddefs), "\n";
	print "\n";

	exit ;
}

foreach my $counter (@counters) {
    @rrddefs = @{$Counterlist{ $counter }->{ rrds }};
    next if ( $opt_c and ( $opt_c ne $counter ));
         
    foreach my $rrd_d (@rrddefs) {
      next if ( $opt_r and ( $opt_r ne $rrd_d  ));

      my $current_rrd = sprintf ($RRD_sprintf, $RRD_dir, $RRD_prefix , $counter,  $rrd_d );
      print "  - processing $current_rrd ... \n" unless ($opt_q) ;
      if ($opt_a) { print "    press <ENTER> to continue\n"; <STDIN> ;} 
      next if ($opt_D) ;
      die "========= still to do ==========";
  }
}


die "#### ~~~~~~~~~~~~ Baustelle ~~~~~~~~~~~~ ####";

