#!/usr/bin/perl
#
#

use warnings ;
use strict ;
use Data::Dumper ;
use Digest::CRC ;
# use Socket;
use IO::Socket;
use Time::HiRes qw( usleep );
use RRDs();

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

# == set up socket connection =====


# my $EOL = "\015\012";

my $SOCK = IO::Socket::INET->new( Proto     => "tcp",
                                  PeerAddr  => $remotehost,
                                  PeerPort  => $remoteport,
           )     || die "cannot connect to port $remoteport on $remotehost";
$SOCK->autoflush(1);

debug_print (3, "-- connected ---\n") ;


# ========== main loop over counters ================

my @counter_subset = sort grep {  
		$Counterlist{ $_ }->{ bus } eq $bustag ;
	}   keys %Counterlist;

foreach my $counter_tag (@counter_subset) {
  my $counter_ptr = $Counterlist{ $counter_tag };
  my $device_ID = $counter_ptr->{ ID } ;
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

	printf " from %d to %d, \n ", $min, $max ;

      my @floats = SDM_query_cooked ($device_ID,  $min, $max  ) ;

      print Dumper (\@floats);

die " ==== bleeding edge ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+~~";

  } # foreach my $slk (@selectors) {

# TODO
# sanity check
# loop over rrds 
# rrdupdate
# time sync


} # foreach my $counter_tag (@counter_subset)

# should never be here.... so no nedd to clean up?


exit;

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


# implement SDM / modbus protocol syntax
# return undef on failure
# @floats  = SDM_query_cooked ($device_ID,  $min, $max  )
sub SDM_query_cooked {
  my ($device_ID,  $min, $max  ) = @_ ;
  # printf "SDM_query_cooked  at device %d from %d to %d, \n ", ( $d_ID, $min, $max );
  my ($qry) = SDM_querystring ($device_ID,  $min, $max  ) ;
  my $n_regs = $max +1 - $min;
  # my $expected_bytes = (($max - $min ) *4 ) + 9 ; 
  my $response = query_socket ($SOCK, $qry, $n_regs *4 +5 ) ;
  return SDM_parse_response ($response, $device_ID, $n_regs) ;
}


# perform pre query protocol building	
sub SDM_querystring {	
  my ( $d_ID, $min, $max ) = @_ ;

  printf "SDM_querystring  at device %d from %d to %d, \n ", ( $d_ID, $min, $max );

  my $n_regs = $max +1 - $min;
  if ($n_regs > $MAX_nvals ) { die "configuration error - request size $n_regs exceeds max of $MAX_nvals" }

  my $start_addr = ($min -1 ) *2; 
  my $hex_regs = $n_regs *2;
  my $expect_bytes = $n_regs*4 +5;
  # buffer to construct query: array of byte as numbers
  my @tosend ;
  my $cmd_token = 0x04; # Modbus cmd to query register

  push @tosend, $d_ID, $cmd_token ;
  push @tosend , number2bytes ( $start_addr , 2);
  push @tosend , number2bytes ( $hex_regs , 2);

  my @digest = modbusCRC ( \@tosend );
  push  @tosend , @digest ;

  return array2string ( @tosend ) ;
} 

# parse SDM response, 
# @floats = SDM_parse_response ($response, $device_ID, $n_regs)
sub SDM_parse_response {
  my ($response, $device_ID, $n_regs) = @_ ;   
  # 3 bytes, $n_regs x 4-bit unsigned (don't unpack let decode them), H4 aka 16 bit crc at tha end
  my @unpacked = unpack ( 'C' x 3 . 'N' x $n_regs . 'H4' , $response ); 

  my $u_len = scalar @unpacked ;
  # return undef if scalar @unpacked < $n_regs + 4;
  my $r_crc = hex pop @unpacked ;
  my @digest = modbusCRC ( \@unpacked );

  my $r_did = shift @unpacked;
  unless ( $r_did  == $device_ID ) 
  	{ die sprintf "SDM response device ID mismatch 0x%02x -> 0x%02x ", $device_ID, $r_did  ; }

  my $r_cmd = shift @unpacked ;
  unless ( $r_cmd  == 0x04 )
  	{ die sprintf "SDM response cmd ID mismatch - expect 0x04, got 0x%02x ",  $r_cmd  ; }

  my $r_len = shift @unpacked ;
  my $r_len_want = $n_regs *4  ;
  unless ( $r_len  == $r_len_want )
	{ die sprintf "SDM indicated response length mismatch - want %d, got %d", $r_len_want, $r_len   ; }


  my @floats = map { decodeIEE754($_) } @unpacked ;
  unless ( scalar @floats == $n_regs) 
  	{ die "SDM response variable number mismatch"; } 

  printf "n-regs=%d sc-unp=%d, sc-fl=%d, did=0x%02x cmd=0x%02x len=%d r-crc=0x%04x digHSB=%02x digLSB=%02x \n ",
    $n_regs, $u_len , scalar @floats , $r_did, $r_cmd , $r_len, $r_crc,  @digest, ;
  # TODO don't die - if happens (shit) return undef;
  return ( @floats) ;
}

# perform physical socket queries
# TODO:  errorr checking  with retry and timeouts
# returns answer string or undef upon failure
# $response = query_socket ( $sock, $querystring, $expected_bytes , [ $retries , [ $wait_us ]] )
sub query_socket {
  my ($sock, $qry, $nexp, $nrtry, $w_us) = @_ ; 
  print $sock $qry ; 
  my $response ;
  my $qr_status = (sysread ( $sock, $response,  $nexp) ) ;
  # if happens (shit) return undef;
  return $response;
}


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


