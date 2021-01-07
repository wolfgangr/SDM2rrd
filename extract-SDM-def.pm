#!/usr/bin/perl
#

use warnings;
use strict;
use Data::Dumper  qw(Dumper);

our $Debug ; # = 3;
require ('./my_debugs.pl');

our $MAX_nvals = 40 ; # maximum number of values accepted in a single reques
our $sdm_def_file = "SDM630proto-usage.csv" ;


my ($SDM_regs, $SDM_reg_by_tag , $SDM_selectors ) = ( read_csv_SDM_def ( $sdm_def_file ));

our @SDM_regs       = @{$SDM_regs} ;
our %SDM_reg_by_tag = %{$SDM_reg_by_tag}  ;
our %SDM_selectors  = %{$SDM_selectors}  ;


# exit;
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


# \@SDM_regs, \%SDM_reg_by_tag , \%SDM_selectors  = read_csv_SDM_def ( $csv_file_name )
#
sub read_csv_SDM_def { 
  my $filename = shift;
  open (my $IN, '<', $filename) or die "cannot open $filename : $!";

  my @regs;
  my %reg_by_tag ;
  my %selectors ;
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
	if (defined $tag) { $tag =~ s/^\"(.*)\"$/$1/ ; }

	# force numerical - does not help...
	# $par_no = int ($par_no) ;

	debug_printf (4, "sel: %d  field: %d, adr: 0x%04x, tag %s, unit %s, \t%s\n", 
		$selector, $par_no, ($par_no-1)*2, , $tag, $unit, $desc ) ;  
	push @regs, \@subset ;

	if ($tag) {
		my %this = ( 
			par_no	=> $par_no, 
			desc 	=> $desc,
			unit	=> $unit,
			selector => $selector
		) ;
		$reg_by_tag{$tag} = \%this ;

		$selectors{$selector}{$par_no}= $tag ;
	}
  }
  close $filename;
  return (\@regs,  \%reg_by_tag , \%selectors )  ;
}

1;
