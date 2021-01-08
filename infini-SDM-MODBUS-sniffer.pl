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

my $debug = 0; 

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
my $starttime = gettimeofday * 1e3 ; 
my $cnt;

my $req_cnt =0;     # index into our etra requests to round robin
my $ans_cnt = -1 ;  # state to keep track where we are in the line

# for my $cnt ( 1.. 100 ) {
while (1) {
	$cnt++;
	# printf  "-%02d = " , $cnt, ;
	my $status = sysread $MODBUS, $buf, 1024 ;
	my $rectime = gettimeofday * 1000 ;
	printf  "R: %02d at %s:" , $cnt,  my_timetag ( $rectime, $starttime) ;
	

	if ($status) {
		if ( $buf eq $startseq ) { 
			$ans_cnt = 0; 
			$starttime = $rectime  ;
		} else { $ans_cnt++ ;}


		printf( " - ans: %d - data: %s \n",  
			$ans_cnt, debug_str_hexdump($buf) ) ; 

		if ($ans_cnt == 1) {
			# we have a SDM response, and insert our multimaster query
			usleep ( 1e5 );
			my $qry = $requests[$req_cnt ];
			syswrite $MODBUS, $qry ;
			my$wrtime = gettimeofday * 1000 ;
			printf(  "W:    at %s:           query: %s \n" ,  
				my_timetag ( $wrtime , $starttime) , 
				debug_str_hexdump ($qry )) ;

			if ( ++$req_cnt > $#requests) { $req_cnt =0 } ;
			usleep ( 3e5 );
		}

		next;
	} else {
		print " ## empty ## \n";
		die "shitt happened: recieved empty string" ;
	}
}






exit ;
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



# $timetagstring timetag($now, [ $start ])
# returns printable time and time offset tags
# if start ist omitted, offset is 0
# time is  in µſ, only ms are printed
sub my_timetag {
  my ($now,  $start ) = @_ ;
  my $diff = (defined ( $start )) ?
	( $now - $start )  : 0 ;  
	#return sprintf ("03%d.%03d - %03d.%03d",
	#  split_000($now/1000, 2), split_000($diff/1000, 2) ) ;
  return my_000_000 ($now) . ' - ' .  my_000_000 ($diff);
}

# returns 3-grops of 1e9, 1e6, 1e3, discards upper and lower digits
sub my_000_000 {
  my $bn = shift;
  my $bnstr = sprintf "%06d", $bn;
  return 
  	#substr($bnstr -12,3) . '.' .
	substr($bnstr, -6,3) . '.' .
	substr($bnstr, -3,3)  ;
 
}	
# split positve big number into seq of 1000
#  ($megas, $kilos, $ones) split_000 ($bignumber, 3)
sub split_000 {
  my ($bn, $chunks) = @_;
  my @res;

  while ($chunks--) {
    unshift @res, int($bn % 1000) ;
    my $bn = int ( $bn / 1000 ) ;
  }
  unshift @res,$bn ;
  return ( @res );
   
}



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
