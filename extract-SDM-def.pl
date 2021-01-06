#!/usr/bin/perl
#

use warnings;
use strict;
use Data::Dumper  qw(Dumper);

our $Debug = 2;
require ('./my_debugs.pl');


my $sdm_def_file = "SDM630proto-usage.csv" ;
open (my $IN, '<', $sdm_def_file) or die "cannot open $sdm_def_file : $!";


# this is what main might want
our @SDM_regs =();    		# resembling the raw data for whatever use
our %SDM_reg_by_tag =();  	# for human readable direct access
our %SDM_selectors =();		# indexed by selector / number => tag

while (<$IN>) {

	next if /^#/ ;
	chomp;

	my @fields = split ',' ;
	debug_dumper ( 5, @fields);
   		
	# my ($par_no, $desc, $unit, $selector, $tag) = @fields[3,7,10,12,13];
        my @subset  = @fields[3,7,10,12,13];
	my ($par_no, $desc, $unit, $selector, $tag) = @subset;
	next unless $par_no;
        
	# strip ""
	(defined $unit) ? ( $unit =~ s/^\"(.*)\"$/$1/) : ($unit = '') ;  # if $unit ;
	$desc =~ s/^\"(.*)\"$/$1/ ; 

	debug_printf (4, "sel: %d  field: %d, adr: 0x%04x, tag %s, unit %s, \t%s\n", 
		$selector, $par_no, ($par_no-1)*2, , $tag, $unit, $desc ) ;  

	push @SDM_regs, \@subset;
	# die "debug";
	
	if ($tag) {
		my %this = ( 
			par_no	=> $par_no, 
			desc 	=> $desc,
			unit	=> $unit,
			selector => $selector
		) ;
		$SDM_reg_by_tag{$tag} = \%this ;

		$SDM_selectors{$selector}{$par_no}= $tag ;
	}
}

debug_dumper ( 3, \@SDM_regs, \%SDM_reg_by_tag , \%SDM_selectors );
1;
exit;

