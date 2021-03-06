#!/usr/bin/perl
#
# Multimaster sniffer for extending infini <-> SDM energy counter communication
# - sniff whats going on any way
# - extract short total-power readings
# - insert additional readings if system accepts so
# - pass the responses messsage queue for e.g rrd logger
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

use IPC::SysV qw(IPC_PRIVATE S_IRUSR S_IWUSR ftok IPC_CREAT IPC_NOWAIT );
use IPC::Msg();
use Cwd qw( realpath );


# helper to extract the counter configuration
my $precooker = "./infini-SDM-precook.pl";

# persistent link into /dev/serial/by-path...
my $device = "~/infini/dev_infini_modbus";
# my stty .... better called outside?

# Sysv-MQ need arbitrary file and a key to generate unique MQ key - share with client
my $mq_ref = "./message_queue.kilroy" ;
my $mq_mtype = 1;
# my $our_ftok = ftok (realpath ($mq_ref)) ;

# the request of infini-MODBUS-card - used as sync starter
my $startseq =  array2string(  map  hex, qw( 01 04   00 34  00 02  30 05)  );


# parameter for limiting bus load
my $interval = 15 ; # seconds between additional query runs
my $interval_shift = 7 ; # seconds shift from even interval modulos
my $inter_query_stepping = 3 ; # how many native qry occasions to skip befor inserting extra qry


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

# ----- setup MODBUS line

# let bash expand file globbing
my $dnexp = `echo $device`;
chomp $dnexp;

# :raw is same as binmode
open ( my $MODBUS, '+<:raw', $dnexp ) 
	or die "in $0: cannot open $device : $! ";

if ($debug ) {
	printf "device %s - resolved to %s - open\n\n", $device, $dnexp; 
}

# ------ setup message queue

`touch $mq_ref` ; # make sure file exists
my $our_ftok = ftok (realpath ($mq_ref)) ;

my $MQ  = IPC::Msg->new($our_ftok     ,  S_IWUSR | S_IRUSR |  IPC_CREAT )
	or die sprintf ( "cant create mq using token >0x%08x< ", $our_ftok  );

# can we increase the thingie to 10 MB?
# $MQ->set ( qbytes => 16000000  ); # 1e7 );

#~~~~~~~~~~ prep header of main  loop
my$buf;
# my $cnt;
# while ( $cnt ) {

my $cnt; # rolling counter for debug purposes

my $req_cnt = -1 ;     # index into our etra requests to round robin
my $qry_pause_cnt =0;  # implement 
my $starttime = gettimeofday * 1e3 ;  # for tagging 
my $nextrun = Time::HiRes::time(); # inter-query counter independet of tagging


my $ans_cnt = -1 ;  # state to keep track where we are in the line



# for my $cnt ( 1.. 100 ) {
while (1) {
	$cnt++;

	# printf  "-%02d = " , $cnt, ;
	my $status = sysread $MODBUS, $buf, 1024 ;
	my $rectime = gettimeofday * 1000 ;
	printf  "r: %02d at %s:" , $cnt,  my_timetag ( $rectime, $starttime) ;
	

	if ($status) {

		my ($mq_qa, $mq_rq, $data_hr);
		if ( $buf eq $startseq ) { 
			$ans_cnt = 0; 
			$starttime = $rectime  ;
			$mq_qa = 'Q';
			$mq_rq = 0;
		} else { $ans_cnt++ ;}

		$data_hr = debug_str_hexdump($buf);
		printf( " - ans: %d - data: %s \n",  
			$ans_cnt, $data_hr ) ; 

		if ($ans_cnt == 1) {
			$mq_qa = 'R';
			$mq_rq = 0;
		}

		if ($ans_cnt == 2) {
			$mq_qa = 'R';
			$mq_rq = $req_cnt +1;
		}

		# message queue format:
		# rq-set (0 for ininis total power, 1..3 for imported selections
		# Q|A for query/answer (bus master view to SDM counter)
		# time of seq-starter-query (epoc in ms, 1+10+3 digits)
		# data as human readable hexdump in 11:4a:5f.... format
		# | as separator
		if ( $mq_qa and defined $mq_rq) { 
			my $mq_msg = sprintf ("%s|%s|%014d|%s", $mq_qa, $mq_rq, $starttime , $data_hr );
			print $mq_msg , "\n";
			$MQ->snd( $mq_mtype, $mq_msg);
		}
		
		if ($ans_cnt == 1) {
                        # we have a SDM response, and might insert our multimaster query now
                        # .... but ...: implement multimaster query timing

			
			next if ( --$qry_pause_cnt > 0) ;

			# reset the interquery selection counter
			if ( ++$req_cnt > $#requests) { 
				$req_cnt =0 ;

				# calculate pseudo 'sleep' time
			        my $now = int (Time::HiRes::time());
				# my $sleep = int ($nextrun - $now) ;
				# $qry_pause_cnt = ($sleep>0) ?  $sleep : 0 ;
				printf "old nr=%d ", $nextrun ;
				# calculate next interval end timer
				my $modulo = ( $now - $interval_shift) % $interval;	
				$nextrun = $now + $interval  - $modulo ; #  + $interval;

				my $sleep = int ($nextrun - $now) ;
				$qry_pause_cnt = ($sleep>0) ?  $sleep : 0 ;

				# printf("now=%d, nextrun=%d, modulo=%d, qry_pause_cnt=%d, sleep=%d \n", 
				# 	$now, $nextrun, $modulo, $qry_pause_cnt, $sleep );
			} else {
				$qry_pause_cnt = $inter_query_stepping ;
			}

			# ----- do the multimaster query
			 
			usleep ( 1e5 );
			my $qry = $requests[$req_cnt ];
			syswrite $MODBUS, $qry ;

			my $wrtime = gettimeofday * 1000 ;
			$data_hr = debug_str_hexdump ($qry );

			printf(  "W:    at %s:           query: %s \n" ,  
				my_timetag ( $wrtime , $starttime) , $data_hr) ; 
				# debug_str_hexdump ($qry )) ;

			my $mq_msg = sprintf ("%s|%s|%014d|%s", 'Q', $req_cnt +1,  $starttime , $data_hr );
			print $mq_msg , "\n";
			$MQ->snd( $mq_mtype, $mq_msg);

			# if ( ++$req_cnt > $#requests) { $req_cnt =0 } ;
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
