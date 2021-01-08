#!/usr/bin/perl
#
# Multimaster sniffer for extending infini <-> SDM energy counter communication
# - sniff whats going on any way
# - extract short total-power readings
# - insert additional readings if system accepts so
# - pass the responses to one or two messsage queues for further use
#
# maybe in the future
# - do something if primary master stops working
# - continue querying if primary master stops working
# - maybe insert extra requests - BMS e.g....
#
# 



use warnings ;
use strict ;
use Data::Dumper ;
use Time::HiRes qw( usleep gettimeofday );
use Digest::CRC ;
use POSIX qw (floor);

my $precooker = "./infini-SDM-precook.pl";
my $device = "~/infini/dev_infini_modbus";
# my stty .... better called outside?

my $startseq =  array2string(  map  hex, qw( 01 04   00 34  00 02  30 05)  );

my $debug = 1;

# end of config ~~~~~~~~~~~~~~~~~~~~


my @precooked = split ("\n",`$precooker`);
my @pre_grepped = grep { ! /^#\s.*/ } @precooked ;

my @requests;
foreach my $l  (@pre_grepped) {
  my $rq;	
  foreach ( split (':', $l) ) {
	  $rq .= chr hex $_ ;
  }
  push @requests, $rq;
}

if ($debug ) {
  printf "startseq: %s\nstructure of config reads;\n", debug_str_hexdump($startseq);
  print Dumper (\@precooked , \@pre_grepped  );
  foreach (@requests) { print debug_str_hexdump($_), "\n" ; }
}

# ----- setup line

# let bash expand file globbing
my $dnexp = `echo $device`;
chomp $dnexp;

# :raw is same as binmode
open ( my $MODBUS, '+<:raw', $dnexp ) 
	or die "in $0: cannot open $device : $! ";

if ($debug ) {
	printf "device %s - resolved to %s - open\n\n", $device, $dnexp; 
}

#~~~~~~~~~~ start loop?
my$buf;
# my $cnt;
# while ( $cnt ) {
my $starttime; 
my $cnt;

# for my $cnt ( 1.. 100 ) {
while (1) {
	$cnt++;
	printf  "-%02d = " , $cnt, ;
	my $status = sysread $MODBUS, $buf, 1024 ;
	my ($secs, $u_secs) = gettimeofday;

	my $sec_000 = $secs % 1000;
	my $us_000 = $u_secs % 1000;
	my $m_sec = floor ( $u_secs / 1000 ) ;

	if ($status) {
		printf " s-ms-µs = %04d-%04d-%04d - data:  ", $sec_000, $m_sec, $us_000 ;
		print( debug_str_hexdump($buf) , "\n") ; 
		next;
	} else {
		print " ## empty ## \n";
		die "shitt happened: recieved empty string" ;
	}


}






exit ;
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~




# take some binary string and return printable hexdump
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

# ... the other way round ...
sub string2array {
	my $str = shift;
	return map (ord, split ("", $str));
}
