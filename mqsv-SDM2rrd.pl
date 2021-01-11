#!/usr/bin/perl
#
# companion to infini-SDM-MODBUS-sniffer.pl
# reads the counter values from message queue and stores them into approriate rrds
# 
#
use strict;
use warnings;

use Data::Dumper ;

# use Time::HiRes () ; TODO: take timestamp from logger, not "N"
use Digest::CRC ;
use POSIX qw (floor);

use IPC::SysV qw(IPC_PRIVATE S_IRUSR S_IWUSR ftok IPC_CREAT IPC_NOWAIT );
use IPC::Msg();
use Cwd qw( realpath );

use RRDs();


our $Debug = 2;

# debug levels:
# 1 - log abnormal data coming in on MQ
# 2 - minimum trace normal operation
# 3 - trace critical data normal operation
# 4 - trace anything normal operation
# 5 - hash dumps 
# 6 - stop after MQ setup
# 7 - stop after data structure setup

# helper to extract the counter configuration
my $precooker = "./infini-SDM-precook.pl";
my $startseq =  array2string(  map  hex, qw( 01 04   00 34  00 02  30 05)  );
my @counter_tags = qw ( mains mains_d  );

# sysV MQ needs a file descriptor for mutual identification - see 'man ftok'
my $mq_ref = "./message_queue.kilroy" ;
my $mq_mtype = 1;


my $cachemax = 100 ; # max records to keep in cache before complaining



# end of config ~~~~~~~~~~~~~~~~~~~~
#
# local include files:

require ('./my_debugs.pl');

our $sdm_def_file;
our (@SDM_regs , %SDM_reg_by_tag , %SDM_selectors, %SDM_tags_by_parno);
require ('./extract-SDM-def.pm');

our $MAX_nvals;
our %Counterlist;
our @all_selectors;
require ('./my_counters.pm');

our %RRD_definitions ;
our ($RRD_dir , $RRD_prefix, $RRD_sprintf ); # = "%s/%s_%s_%s.rrd"; # $dir, $prefix, $countertag,  $rrdtag
require ('./rrd_def.pm');

#  check setup:

if ($Debug >= 5) {
  debug_print ( 5,  Data::Dumper->Dump (
	[ \@SDM_regs , \%SDM_reg_by_tag , \%SDM_selectors , \@all_selectors , \%Counterlist  ] ,
	[ qw(*SDM_regs  *SDM_reg_by_tag   *SDM_selectors  *all_selectors       *Counterlist ) ]  )
  );
}
# die "### DEBUG level 7 ### - die after data structure setup " if ( $Debug >= 7) ;


#  read same precooked config than our line sniffer does - just a list of requests in hex dump form
#  01:04:00:00:00:4c:f1:ff
#  01:04:00:ea:00:12:51:f3
#  01:04:01:56:00:16:90:28

my @precooked = split ("\n",`$precooker`);
my @pre_grepped = grep { ! /^#\s.*/ } @precooked ;

my @requests = ( $startseq ) ; # prepend our number 0 req def

foreach my $l  (@pre_grepped) {
  my $rq;	
  foreach ( split (':', $l) ) {
	  $rq .= chr hex $_ ;
  }
  push @requests, $rq;
}

if ($Debug >= 5) {
  debug_printf (5,  "startseq: %s\nstructure of config reads\n", debug_str_hexdump($startseq) ) ;
  debug_print (5,  Dumper (\@precooked , \@pre_grepped  ) );
  foreach (@requests) { debug_print (5, debug_str_hexdump($_), "\n"  ) ;  }
}

#----------------------
# build a (constant) hash structure to backref our data received
#
#  %wayback = (
#       '_0034:0002' => {  TODO changed this to full hex string - KISS
#           'qry_tag'   => '_0034:0002',
#           'reg_start' => 52, 'reg_num'   => 2,
#           'param_min' => 27, 'param_max' => 27,
#           'val_tags'  => [ 'Ptot'  ],
#                       },  
#       '_0156:0016' => { .....

our %wayback ;

foreach my $rq (@requests) {
	# parse connection strings in MODBUS request format
	my ($ID, $x_04, $reg_start, $reg_num, $crc) = unpack ( 'CCnnn' , $rq); 
	
	my $param_min = $reg_start/2 +1;
	my $param_max = $param_min -1 + $reg_num/2;
	
	my $qry_tag =  debug_str_hexdump($rq);
	# debug_print (  debug_str_hexdump($rq), "\n" ;
	debug_printf( 3, "ID=0x%02x cmd=0x%02x r-start=0x%04x n-reg=0x%04x crc=0x%04x - query-tag= '%s'", 
		$ID, $x_04, $reg_start, $reg_num, $crc, $qry_tag );
	debug_printf( 3, " params min=%d max=%d\n", $param_min , $param_max );

	my @val_tags =();
	for ($param_min .. $param_max) {
		$val_tags[$_ - $param_min ] =$SDM_tags_by_parno{ $_ } || '';
	}	

	my %rqdef = (reg_start=> $reg_start,  reg_num=>  $reg_num,  qry_tag=> $qry_tag ,
		val_tags => \@val_tags , param_min => $param_min,  param_max => $param_max, 
		devID => $ID );
	$wayback{ $qry_tag } = \%rqdef;
}


if ( $Debug >=5 ) {
	debug_print (5,  Data::Dumper->Dump ( [ \%wayback ] , [ qw( *wayback) ]  ) );
    if ( $Debug >=7 ) { 
	die  "=== DEBUG level 7 ===== setup done ============= \n";
}   }

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~Open message queue ~~~~~~~~~~~~~~~

`touch $mq_ref` ; # make sure file exists
my $our_ftok = ftok (realpath ($mq_ref)) ;

my $MQ  = IPC::Msg->new($our_ftok     ,    S_IRUSR | S_IWUSR |  IPC_CREAT   )
	or die sprintf ( "cant create mq using token >0x%08x< ", $our_ftok  );

debug_print (2,  " --- message queue open --- \n" ) ;
if ( $Debug >=6 ) {
        die  "=== DEBUG level 6 ===== mq open ============= \n";
} 


# =========================================== Begin of main loop ==============
my $cnt =1;
my %cache= ();
my $pt_lastrun = 0;

while (1) {

  my $buf;
  $MQ->rcv($buf, 1024, $mq_mtype);

  my ($mq_qa, $mq_rq, $starttime , $data_hr) = split ( '\|'  , $buf);
  my @datary =  map (hex,  split ('\:', $data_hr) );
 
  debug_printf (3,  ("type=%s, no=%d, time=%014d, data (len=%d): %s  \n", 
		  $mq_qa, $mq_rq, $starttime , scalar @datary ,  $data_hr  ) );

  # register timetag of any response, no matter whether valid
  $cache{ sprintf("%1s:%1d", $mq_qa, $mq_rq)  } = { last => $starttime,  foo => 'bar'};

  # .... postprocessing message to populate cache
  if ($mq_qa eq 'Q')  {
	  # when everything is OK, the label always will be overrwritten
	  # when we have garbage on the bus, BS may accumulate
	  my $q_tag = sprintf("%1s:%1d", $mq_qa, $mq_rq  );
	  $cache{ $q_tag }->{ tag}  =  $data_hr  ; 

  } elsif ($mq_qa eq 'R')   {
	# build reference back from counter response to query
	my $peer_q = sprintf("Q:%1d",  $mq_rq  );  
	my $rq_tag   = $cache{   $peer_q }->{ tag } ;
	my $rq_tlast = $cache{   $peer_q }->{ last } ;
	my $dev_ID   = $wayback{ $rq_tag }->{ devID } ; 

	debug_printf (4, "adding R row - peer_q=%s, rq_tag=%s, rq_tlast=%s, dev_ID=%s, \n", $peer_q, $rq_tag, $rq_tlast, -9999);

	if ( $rq_tlast and $rq_tlast == $starttime ) { # then we believe in a clean bus state
		my $r_tag_time = sprintf("%1s:%1d:%014d", $mq_qa, $mq_rq , $starttime );

		my $val_tags = $wayback{ $rq_tag }->{ val_tags } ;
		my @vals = SDM_parse_response_ary( \@datary, $dev_ID       );

		# grab anything available, for use after dancing rock'n roll
		$cache{ $r_tag_time } = { 
			data_array => \@datary , 
			data_hr    => $data_hr ,
			query_tag  => $rq_tag, 
			devID      => $dev_ID , 
			SDMvalues  => \@vals, 
			val_tags   => $val_tags ,
		};

	} else {
		# die "garbage date I soppose? "; # TODO
		debug_print( 1, "misstructured query-response-pattern - garbage on the bus? " );
	}


  } else {
	debug_print( 1,  " illegal data type token - hang on, how did I come here??? ") ;
  }

  # postprocessing complete
  debug_print (4,  Data::Dumper->Dump ( [ \%cache ] , [  qw ( *cache) ] ) ) if ($Debug >= 4) ;
  
  $cnt++;



  # === check cache accumulation aka 'what can we do?' -------------------------------

  debug_print( 4 , map ( ( "\t- " . $_ . "\n"      ), (  sort keys ( %cache ))) ) if ( $Debug >= 4)    ;


  # not nice to hardcode this.... but KISS 
  #   01:04:00:34:00:02:30:05

  # state $Q_lastrun ;
  my $last_R = $cache{ 'R:0' }->{ last };
  if ( defined ($last_R)  and $last_R != $pt_lastrun   ) {
	my $r0_timed = $cache{ sprintf ("R:0:%014d", $last_R) } ;
        	if ( (defined $r0_timed) and ( defined ( my $sdm_vals = $r0_timed->{ SDMvalues } )) ) {  	
			#	my $P_tot = $$sdm_vals[ 0 ] ;
			# print "\tvalue:",  $P_tot, "\n" ;
        		# we have all we need - ptot, times , definitions
        	debug_print (2, " we hit a ptot case\n") ;

		my $status = perform_rrd_update ( \%cache, $counter_tags[ 0 ] ,  [ $requests[0] ] ) ;

		if ($status) { $pt_lastrun = $last_R  ; }
	}
  }     

  # precheck: loop over indexes of requests , count the hits of R and Q labels, 
  # 	and if the the number is enough , we might have a complete data set
  if ( (scalar ( grep { ( $cache{ 'R:'.$_  } and $cache{ 'Q:'.$_ } ) } (0 .. $#requests) ) ) >= scalar  @requests ) {
	  debug_print (2,  " we hit a all other counter case\n") ;
	  # so we try a full size rrd update 
 
	 # e.g what we know in our cache:
	 #
	 #    'R:0:01610307266184' => {
	 #               'query_tag' => '01:04:00:34:00:02:30:05',
	 #               'data_array' => [ 1 4  4 69 14  225 240 199 95   ],
	 #               'devID' => 1,
	 #               'data_hr' => '01:04:04:45:0e:e1:f0:c7:5f',
	 #               'SDMvalues' => [  '2286.12109375'
	 #               'val_tags' =>  [  'Ptot'   ],
	 #         }

 	 my $status = perform_rrd_update ( \%cache, $counter_tags[1] , \@requests ) ;
 	 if ($status) {
		 # after successful update of all rrds we start with a fresh cache
		 %cache = ();

	 } else {
		 debug_print ( 1, "all counter rrd update failed \n"); 
	 }
  }

  # cleanup cache and log in case of clobbered bus
  # value of 20 works for hours in tests without trigger
  if (scalar keys %cache > $cachemax  ) {
	  %cache = (); 
	  # %cache = ( trace => 'cleanup' );
	   debug_print ( 1, "looks like our cache is clobbered with BS stuff - throw away.... \n" ) ;

  }
}

exit 1;

# ===================== END of Main loop - subs below ===================================================================


# $status = perform_rrd_update ( \%cache, $counter_tag , \@requests )
sub perform_rrd_update {
   my ($p_cache, $ct, $rqp)  = @_ ;

   # look up the rrd definitions  
   my @rrds = @{$Counterlist{ $ct }->{ rrds }} ;

   # build an overall tag-> value hash
   my %t_v =();
   my $rrd_timestamp;
   foreach my $rspnum (0 .. $#$rqp) {

     my $lastrun = $$p_cache{ sprintf ("R:%s", $rspnum) }->{ last } ;
     return 0 unless defined $lastrun ;
     $rrd_timestamp = floor ($lastrun / 1000); # rrd wants epoc in sec, we have ms

     my $rsp_p = $$p_cache{ sprintf ("R:%s:%014d", $rspnum, $lastrun) } ;
     return 0 unless defined $rsp_p ; 
     my %rsph = %{$rsp_p} ;

     ### print Data::Dumper->Dump ( [ \%rsph ] , [ qw( *rsph ) ] ) ;

     foreach  ( 0 ..  $#{$rsph{ val_tags}} ) {
	     my $vtg = ${$rsph{ val_tags}}[ $_ ] ;
	     my $svl = ${$rsph{ SDMvalues}}[ $_ ] ;
	     if ( $vtg ) { 
		     # we came thus far - we'll not bother for missing vars any more
		     $t_v{ $vtg } = defined ($svl) ? $svl : 'U' ; 
	     } 
     }

   }
   debug_print (5, Data::Dumper->Dump ( [ \%t_v ] , [ qw( *vt ) ] ) ) if ($Debug >= 5);

   debug_print (2, "counter: $ct, rrds: ", join (',', @rrds) , "\n" );
   for my $rrd_tag (@rrds) {
         my @fields =  @{$RRD_definitions{ $rrd_tag   }->{ fields } };
         my $rrd_template = join ( ':', @fields);
	 my $rrd_values = join ( ':', $rrd_timestamp, 
		 map { ($t_v{ $_}  )  } @fields ) ;

         debug_print (3, "tags: ", $rrd_template   , "\n" );
	 debug_print (3, "values: ", $rrd_values , "\n"   );

         my $rrdfile = sprintf $RRD_sprintf, $RRD_dir, $RRD_prefix, $ct, $rrd_tag;
         debug_print (3, "rrd file: ", $rrdfile , "\n" );

         RRDs::update($rrdfile, '--template', $rrd_template, $rrd_values);
         if ( RRDs::error ) {
             debug_printf (1, "error updating RRD %s: %s \n", $rrdfile , RRDs::error ) ;
	     return 0;
         } else {
             debug_printf (2, "rrd update succesful for %s\n" , $rrdfile);
         }
   }
   return 1;
}



# ----------- parse SDM Modbus response ---------------

# parse SDM response,
# @floats = SDM_parse_response ( \@response, $device_ID, $n_regs)
sub SDM_parse_response_ary {
  my ($p_response, $device_ID) = @_ ;

  my @rsp =@{$p_response};
  my $response = array2string(@rsp);
  my $n_regs = ( scalar @rsp - 5 ) / 4;


  # last 2 bytes is crc, everything else goes into CRC check
  my $crc_hi = pop @rsp; # poping from the end, crc is lo byte first order
  my $crc_lo = pop @rsp;
  my @digest = modbusCRC ( \@rsp );

  unless ( $digest[1] == $crc_hi and $digest[0] == $crc_lo )  	{
	  debug_printf( 5, "digest LSB=0x%0x HSB=0x%0x , crc HSB=0x%0x LSB=0x%0x \n",
		@digest, $crc_hi , $crc_lo );
	  debug_printf( 3, "SDM response crc mismatch" );
  }

  # 3 bytes, $n_regs x 4-bit unsigned (don't unpack let decode them), H4 aka 16 bit crc at tha end
  # see https://perldoc.perl.org/functions/pack .... n or S
  my @unpacked = unpack ( 'C' x 3 . 'N' x $n_regs . 'n' , $response );

  my $u_len = scalar @unpacked ;
  my $r_crc =  pop @unpacked ;

  my $r_did = shift @unpacked;
  unless ( $r_did  == $device_ID ) {
  	debug_printf(3, "SDM response device ID mismatch 0x%02x -> 0x%02x ", $device_ID, $r_did ) ;
	return ();
  }

  my $r_cmd = shift @unpacked ;
  unless ( $r_cmd  == 0x04 ) {
  	debug_printf(3, "SDM response cmd ID mismatch - expect 0x04, got 0x%02x ",  $r_cmd ) ;
        return ();
  }

  my $r_len = shift @unpacked ;
  my $r_len_want = $n_regs *4  ;
  unless ( $r_len  == $r_len_want ) {
	debug_printf(3, "SDM indicated response length mismatch - want %d, got %d", $r_len_want, $r_len ) ;
	return ();
  }

  my @floats = map { decodeIEE754($_) } @unpacked ;
  unless ( scalar @floats == $n_regs) { 
	  debug_print (3, "SDM response variable number mismatch" ) ;
  } 

  return ( @floats) ;
}


# ----------- protocol specific helpers --------
#
# decodeIEE754
sub decodeIEE754 {
  my $word = shift;
  return 0 unless $word;
  my $sign = ($word & 0x80000000) ? -1 : 1;
  my $expo = (($word & 0x7F800000) >> 23) - 127;
  my $mant = ($word & 0x007FFFFF | 0x00800000);
  return  $sign * (2 ** $expo) * ( $mant / (1 << 23));
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

# ----------------- generic little helpers ------------------------


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
