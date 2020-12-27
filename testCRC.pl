#!/usr/bin/perl
#
#

use warnings ;
use strict ;
use Data::Dumper ;
use Digest::CRC ;

my $device = 0x08;
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

my $digest = modbusCRC ( \@tosend );
print Dumper ( $digest );

exit;


# hexdump, pass array by ref
sub debug_hexdump {
    # my $level = shift @_;
    # return unless ( $level <= $debug) ;
    my $ary = shift @_;
    # print Dumper ($ary );
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
    $number >>= 16 ;
  }
  return reverse @res ;
}


# sub modbusCRC ( \@data )
# accepts an array of byte data
# returns list of 2 bytes in array
sub modbusCRC {
  my $ary = shift @_;
  my $ctx = Digest::CRC->new(width=>16 , init=>0xffff, poly=>0x8005 , refin => 1, refout => 1) ;
  foreach my $x ( @$ary ) {
    $ctx->add ( chr $x) ;
  }
  return  ($ctx->hexdigest) ;
}


sub mymodbusCRC {
  my $ary = shift @_;
  my $crc = 0xffff;
  foreach my $x ( @$ary ) {
    # $ctx->add ($x) ;
    foreach my $i (8 .. 1) {
      if ($x & 0x01 ) { $crc ^= 0xA001 ; }
      $x >>= 1;      
    }
  }
  # return number2bytes ( $crc, 2 ) ;
  return $crc ;
}


