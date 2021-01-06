#!/usr/bin/perl
#

use warnings;
use strict;
use Data::Dumper  qw(Dumper);

our $Debug;

# debug_print($level, $content)
sub debug_print {
  my $level = shift @_;
  print STDERR @_ if ( $level <= $Debug) ;
}

sub debug_printf {
  my $level = shift @_;
  printf STDERR  @_ if ( $level <= $Debug) ;
}

sub debug_dumper {
  my $level = shift @_;
  print STDERR (Data::Dumper->Dump( \@_ )) if ( $level <= $Debug) ;
}
1;

