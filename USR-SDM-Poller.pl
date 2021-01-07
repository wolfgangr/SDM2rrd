#!/usr/bin/perl
#
#

use warnings ;
use strict ;
use Data::Dumper ;
use Digest::CRC ;
# use Socket;
use IO::Socket;


my $remoteport = 502 ;
# my $remotehost = "192.168.1.241";
my $remotehost = "USR-TCP-stromz.rosner.lokal"; 
# my $bustag = 'MODBUS-infini' ;  # we only handle counters belonging to this tag
my $bustag = 'tcp-241';

our $Debug = 3;


require ('./my_debugs.pl');

# our $sdm_def_file;
our (@SDM_regs , %SDM_reg_by_tag , %SDM_selectors);
our $MAX_nvals ;
require ('./extract-SDM-def.pm');

our %Counterlist;
our @all_selectors;
require ('./my_counters.pm');

our %RRD_definitions ;
require ('./rrd_def.pm');

# == socket connection hat to go before loop =======


# loop over counters

my @counter_subset = sort grep {  
		$Counterlist{ $_ }->{ bus } eq $bustag ;
	}   keys %Counterlist;

foreach my $counter_tag (@counter_subset) {
  my $counter_ptr = $Counterlist{ $counter_tag };
  # instantiate data cache
  my %valhash =();
  # loop over selectors
  my @selectors = @{$counter_ptr->{ selectors }} ;
  foreach my $slk (@selectors) {
    # we have a list of tags, but need numeric indices - at least start an lengt
    # suppose we have a a hast by tag with hash of index / value /whaev
      my $min = 999999;
      my $max = -1 ;
      foreach my $stg (@$slk) {
        my $sidx = $SDM_reg_by_tag{ $stg };
        $valhash{ $stg }->{ def } = $sidx;
        my $parno = $sidx->{ par_no };
	if ($parno < $min ) { $min = $parno ; }
	if ($parno > $max ) { $max = $parno ; }
      }  # foreach my $stg (@$slk)

      print Data::Dumper->Dump ( 
        	[ \@counter_subset, $counter_ptr, \@selectors, $slk, \%valhash, ], 
		[ qw(*counter_subset *counter_ptr  *selectors  *slk   *valhash  ) ] ) ;

      my $n_regs = $max +1 - $min;
      if ($n_regs > $MAX_nvals ) { die "configuration error - request size $n_regs exceeds max of $MAX_nvals" }

      my $start_addr = ($min -1 ) *2;
      my $hex_regs = $n_regs *2;
      printf "retreiving %d params from %d to %d, start at 0x%04x, count 0x%04x\n ", 
     		$n_regs, $min, $max,  $start_addr, $hex_regs  ;

die " ==== bleeding edge ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+~~";

  } # foreach my $slk (@selectors) {


# sanity check
# loop over rrds 
# rrdupdate
# time sync


} # foreach my $counter_tag (@counter_subset)




#=========== bleeding edge ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
# data below hat to be extracted from counter /rrd config

my $device = 0x01;
my $cmd = 0x04;
my $startadd = 0;
my $numdata = 76 ; # aka 0x4c


# data format of my choice: array of byte as numbers

my @tosend ;
push  @tosend, $device, $cmd ; 

push  @tosend , number2bytes ( $startadd , 2);
push  @tosend , number2bytes ( $numdata , 2);

my @digest = modbusCRC ( \@tosend );
push  @tosend , @digest ;


# print Dumper (@tosend) ;

debug_hexdump ( \@tosend ) ;
print "\n";

my $sendstring = array2string ( @tosend ) ;

print str_hexdump($sendstring);

#------- create connection

# https://www.tutorialspoint.com/perl/perl_socket_programming.htm

# my $iaddr   = inet_aton($remotehost)       || die "no host: $remotehost";
# my $paddr   = sockaddr_in($remoteport, $iaddr);
# my $proto   = getprotobyname("tcp");
# socket(my $sock, PF_INET, SOCK_STREAM, $proto)  || die "socket: $!";
# connect($sock, $paddr)              || die "connect: $!";


# socket( SOCKET, pack_sockaddr_in($remoteport, inet_aton($remotehost)))
#    or die "Can't bind to port $remoteport at host $remotehost\n Reason:  $! \n";


my $EOL = "\015\012";

my $sock = IO::Socket::INET->new( Proto     => "tcp",
                                  PeerAddr  => $remotehost,
                                  PeerPort  => $remoteport,
           )     || die "cannot connect to port $remoteport on $remotehost";
$sock->autoflush(1);

print "-- connected ---\n";

print $sock $sendstring ;
# my $response = <$sock> ;

my $response ;
my $byte;
# while (sysread($sock, $byte, 1) == 1) {
#	# print STDOUT $byte;
#	$response .= $byte ;
#	print str_hexdump($response);
#
#}
# print "loop ended ---- \n";

(read($sock, $response, 157))  or die "not enought data received";

# print str_hexdump($response);
my @response = string2array ($response);
print debug_hexdump( \@response) , "\n";

my @unpacked = unpack ( 'H2' x 3 . 'N' x 38 . 'H4' , $response ); 

print Dumper (\@unpacked);

my @floats = map { decodeIEE754($_) } @unpacked[3..40] ;
print Dumper (\@floats);







exit;

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


# decodeIEE754
sub decodeIEE754 {
  my $word = shift;
  return 0 unless $word;
  my $sign = ($word & 0x80000000) ? -1 : 1;
  my $expo = (($word & 0x7F800000) >> 23) - 127;
  my $mant = ($word & 0x007FFFFF | 0x00800000);
  return  $sign * (2 ** $expo) * ( $mant / (1 << 23));
}

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
  my $str = shift ;
  my $res = `echo $str | xxd ` ;
  return $res;
}


# convert array of bytes to string
# array2string ( @bytes) )
sub array2string {
	my $rv;
	while (defined ($_ = shift) ) {
		$rv .= chr $_ ;
	}
	return $rv
}

# ... the other way round ...
sub string2array {
	my $str = shift;
	return map (ord, split ("", $str)); 
}


# convert number to hex bytes of give lengts, return als array of numbers
# sub ( $number, $bytes )
 
sub number2bytes {
  my (  $number, $bytes ) = @_;
  my @res;
  while ( $bytes > 0 ) {
    push ( @res, ($number & 0xff) );
    $bytes-- ;
    $number >>= 8 ;
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
  return  reverse number2bytes ($ctx->digest, 2) ;
}

# don't use this, this is untested
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


