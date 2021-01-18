#!/usr/bin/perl
#
# simple watchdog for rrd files
# to be used in systemd config
#
# https://oss.oetiker.ch/rrdtool/doc/rrdlast.en.html
# rrdtool last filename [--daemon|-d address]
# The last function returns the UNIX timestamp of the most recent update of the RRD.
# RRDs::last returns a single INTEGER representing the last update time.
#
# we don't find a pwerl warrper for lib-sd_notify, so we call console goodies
# 
# systemd-notify 'WATCHDOG=1'
# systemd-notify 'READY=1'

use warnings;
use strict;
use RRDs ;
# use Data::Dumper ;


# my $rrddir = '../rrd';  # relative to ./setup, no trailing /

# my @watched = qw ( status.rrd  statusX.rrd  temps.rrd  tempsX.rrd );
# try to automagically extract rrd file names from config

my $bustag = 'tcp-241';

our $Debug =0;
our %Counterlist;
our ($RRD_dir , $RRD_prefix, $RRD_sprintf );
# our @all_selectors;
require ('./my_counters.pm');
require ('./rrd_def.pm');

my @counter_subset = sort grep {  
		$Counterlist{ $_ }->{ bus } eq $bustag ;
	}  keys %Counterlist;


	# print join ' : ' ,   @counter_subset ;
	# print "\n";


my @watched;
foreach my $counter_tag (@counter_subset) {
	my $counter_ptr = $Counterlist{ $counter_tag };
	foreach my $rrd_tag ( @{$counter_ptr->{ rrds }} ) {
		my $rrdfile = sprintf $RRD_sprintf, $RRD_dir, $RRD_prefix, $counter_tag, $rrd_tag;
		# print $rrdfile , "\n";
		push @watched, $rrdfile ;
	}
}


# print join ' : ' ,   @watched ;
# print "\n";

# die "DEBUG";

#~~~~~~~~~~~~~~~~~~~~~~~


my $gracetime = 120 ; 


my $looptime = 20 ; # sleep between tests - recommended half of WatchdogSec=240 in service file
my $loopt_onfail = 2; # may switch to faster polling to 

my $logstring = "SDM USR poller WATCHDOG: %s\n";

# ------- end of config ---------------------------------
#
my $sd_notify_WD  =  "systemd-notify 'WATCHDOG=1'";
my $sd_notify_RDY =  "systemd-notify 'READY=1'";


my $started = 0;
while (1) {
	my $overdue_cnt =0;

	for my $rrdfile ( @watched ) {
		# my $rrdfile = $rrddir . '/'. $rrd;
		my $last = RRDs::last ($rrdfile); 
		my $age = time() - $last;
		if ( $age > $gracetime ) {
			$overdue_cnt++;
			printf( $logstring, sprintf( " file %s overdue - age = %d ", $rrdfile, $age) )  ;

		}
	}

	# notify - 
	unless ( $overdue_cnt ) { 
		unless ( $started ) {
			printf $logstring,  $sd_notify_RDY ;
			system $sd_notify_RDY;
			$started = 1;	
		}
		# rint "WATCHDOG: $sd_notify_WD \n";
		printf $logstring, $sd_notify_WD ;
		system  $sd_notify_WD;
		sleep $looptime;
	} else {
		printf( $logstring, sprintf( " %d / %d files overdue ", $overdue_cnt, scalar @watched ) ) ;
		sleep $loopt_onfail;
	}


	# interval
	# sleep $looptime;
}
# time()
