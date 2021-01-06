#!/usr/bin/perl
#

use warnings;
use strict;
use Data::Dumper  qw(Dumper);

my $sdm_def_file = "SDM630proto-usage.csv" ;
open (my $IN, '<', $sdm_def_file) or die "cannot open $sdm_def_file : $!";



our @SDM_regs =();
our %SDM_reg_by_tag =();

while (<$IN>) {

	next if /^#/ ;
	chomp;

	my @fields = split ',' ;
	# print Dumper (@fields);
   		
	# my ($par_no, $desc, $unit, $selector, $tag) = @fields[3,7,10,12,13];
        my @subset  = @fields[3,7,10,12,13];
	my ($par_no, $desc, $unit, $selector, $tag) = @subset;
	next unless $par_no;
        
	# strip ""
	$unit =~ s/^\"(.*)\"$/$1/ ;
	$desc =~ s/^\"(.*)\"$/$1/ ;

	printf "sel: %d  field: %d, adr: 0x%04x, tag %s, unit %s, \t%s\n", 
		$selector, $par_no, ($par_no-1)*2, , $tag, $unit, $desc;  

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
	}
}

print Dumper (\@SDM_regs, \%SDM_reg_by_tag );


