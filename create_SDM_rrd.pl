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


my $retval = getopts('dtfad:p:c:r:lv:h');
die "$usage" unless ($retval) ;
die "$usage" if $opt_h  ;

