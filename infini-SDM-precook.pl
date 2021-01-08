#!/usr/bin/perl
#


# precook queries for infini-SDM-sniffer / multi-master

# just extract the queries I want from the definitions
# boilerplate: ./test-counter-def.pl
# crude hacked pieces from USR-SDM-Poller.pl
# not neatly modularized....


use warnings;
use strict;
use Data::Dumper  qw(Dumper);
# use Data::Dumper::Simple :
use Digest::CRC ;

our $Debug = 2;

my $counter_tag = 'mains_d';

#==================

require ('./my_debugs.pl');

our $sdm_def_file;
our (@SDM_regs , %SDM_reg_by_tag , %SDM_selectors);
require ('./extract-SDM-def.pm');

our $MAX_nvals;
our %Counterlist;
our @all_selectors;
require ('./my_counters.pm');

if (0) {
  debug_print ( 3,  Data::Dumper->Dump (
	[ \@SDM_regs , \%SDM_reg_by_tag , \%SDM_selectors , \@all_selectors , \%Counterlist  ] ,
	[ qw(*SDM_regs  *SDM_reg_by_tag   *SDM_selectors  *all_selectors       *Counterlist ) ]  )
  );
}


my $counter_ptr = $Counterlist{ $counter_tag };
my $device_ID = $counter_ptr->{ ID } ;
my $device_bus = $counter_ptr->{ bus } ;

debug_printf ( 3, "my \$counter_ptr %s \n", Dumper ( $counter_ptr) );
# debug_printf ( 2, "# details: ID=%d, bus=%s \n",  $device_ID, $device_bus );
printf (  "# details: ID=%d, bus=%s \n",  $device_ID, $device_bus );


# from USR-SDP-poller.pl
# my %valhash =();
my @selectors = @{$counter_ptr->{ selectors }} ;
foreach my $slk (@selectors) {
    # we have a list of tags, but need numeric indices - at least start an lengt
    # suppose we have a a hast by tag with hash of index / value /whaev
    my $min = 999999;
    my $max = -1 ;
    foreach my $stg (@$slk) {
        my $sidx = $SDM_reg_by_tag{ $stg };
	# $valhash{ $stg }->{ def } = $sidx;
        my $parno = $sidx->{ par_no };
	if ($parno < $min ) { $min = $parno ; }
	if ($parno > $max ) { $max = $parno ; }
    }  # foreach my $stg (@$slk)
    # debug_printf ( 2, "\t register selector ###: min=%d, max=%d \n\t -> ",  $min, $max );
    # debug_print ( 2, join (':', @$slk) , "\n", );

    my $query = SDM_querystring ($device_ID, $min, $max );
    # debug_printf ( 2,  "\t    => %s\n"  , debug_str_hexdump($query)); 
    printf (  "# \t register selection min=%d, max=%d \n#\t -> ",  $min, $max );
    print  (  join (':', @$slk) , "\n", );
    printf (  "%s\n"  , debug_str_hexdump($query));
}

exit;
# ~~~~~ subs ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# crude hack, might better be modulized....

# perform pre query protocol building	
sub SDM_querystring {	
  my ( $d_ID, $min, $max ) = @_ ;

  # printf "SDM_querystring  at device %d from %d to %d, \n ", ( $d_ID, $min, $max );

  my $n_regs = $max +1 - $min;
  if ($n_regs > $MAX_nvals ) 
  	{ die "configuration error for ID $d_ID - request size $n_regs exceeds max of $MAX_nvals" }

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


# need
# array2string
# number2bytes
# modbusCRC


# variant receing and returning string, no fork
sub debug_str_hexdump {
  my $str = shift ;
  my @bytes = map (  sprintf ( "%02x", ord($_) ) , split ("", $str));
  return join ( ':'  ,  @bytes );
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





