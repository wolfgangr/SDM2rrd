#!/usr/bin/perl
#
#

use warnings ;
use strict ;
use Data::Dumper ;


my $device = 0x01;
my $cmd = 0x04;
my $startadd = 0;
my $numdata = 76 ; # aka 0x4c


# data format of my choice: array of byte as numbers

my @tosend ;
push  @tosend, $device, $cmd ; 

push  @tosend , number2bytes ( $startadd , 2);
push  @tosend , number2bytes ( $numdata , 2);


print Dumper (@tosend) ;

debug_hexdump ( \@tosend ) ;
print "\n";



exit;


# hexdump, pass array by ref
sub debug_hexdump {
    # my $level = shift @_;
    # return unless ( $level <= $debug) ;
    my $ary = shift @_;
    print Dumper ($ary );
    foreach my $x ( @$ary ) {
      printf   ( " %02x", $x );
    }
}

# hexdump  of a string
sub str_hexdump { 
  my $res = `xxd $_[0]` ;
  return $res;
}

# convert number to hex bytes of give lengts, return als array of numbers
# sub ( $number, $bytes )
 
sub number2bytes {
  my (  $number, $bytes ) = @_;
  my @res;
  while ( $bytes > 0 ) {
    push ( @res, ($number & 0xff) );
    $bytes-- ;
    $number <<= 16 ;
  }
  return reverse @res ;
  

}
