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

# low level retries upon socket read errors - us wait times
# at least 3 presumably to read off garbage after loss of sync
# sum of all times elapse if timer is down
our @RETRIES =  ( 10, 100, 1000, 10000 ) ; 


my $interval = 15 ; # seconds between runs
my $interval_shift = 7 ; # seconds shift from even interval

our $Debug = 2;
require ('./my_debugs.pl');

# our $sdm_def_file;
our (@SDM_regs , %SDM_reg_by_tag , %SDM_selectors, %SDM_tags_by_parno);
our $MAX_nvals ;
require ('./extract-SDM-def.pm');

our %Counterlist;
our @all_selectors;
require ('./my_counters.pm');

our %RRD_definitions ;

our ($RRD_dir , $RRD_prefix, $RRD_sprintf ); # = "%s/%s_%s_%s.rrd"; # $dir, $prefix, $countertag,  $rrdtag
require ('./rrd_def.pm');

# == set up socket connection =====

# my $human_readable_starttime = `date`;
debug_printf (0, "%s started at %s", $0, `date`);


# my $EOL = "\015\012";

my $SOCK = IO::Socket::INET->new( Proto     => "tcp",
				  Timeout   => 20 ,
				  # Blocking => 1 ,
				  Blocking => 0 ,
				  Type => IO::Socket::SOCK_STREAM,
                                  PeerAddr  => $remotehost,
                                  PeerPort  => $remoteport,
           )     || die "cannot connect to port $remoteport on $remotehost";
$SOCK->autoflush(1);

binmode $SOCK;

debug_print (3, "-- connected ---\n") ;


# we only want to access the subset we are configured for
my @counter_subset = sort grep {  
		$Counterlist{ $_ }->{ bus } eq $bustag ;
	}   keys %Counterlist;

# ========== main loop over counters ================	
HEAD_OF_MAIN_LOOP:
 
my $lastrun = Time::HiRes::time();
my $modulo = (int ($lastrun) + $interval_shift) % $interval;
my $nextrun = $lastrun - $modulo + $interval;

debug_printf (2, "cycletimer: lastrun=%.2f, nextrun=%.2f, diff=%.2f \n", 
	$lastrun, $nextrun , $nextrun - $lastrun);



COUNTER: foreach my $counter_tag (@counter_subset) {
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

      if ($Debug >=5) { print(Data::Dumper->Dump ( 
          	[ \@counter_subset, $counter_ptr, \@selectors, $slk, \%valhash, ], 
      		[ qw(*counter_subset *counter_ptr  *selectors  *slk   *valhash  ) ] ) 
      		);
	}

      debug_printf (4, " from %d to %d, \n ", $min, $max );

      my @floats = SDM_query_cooked ($device_ID,  $min, $max  ) ;
      unless ( @floats ) {
          debug_printf(1, "read failed from counter %s, ID %d, Param. No.  %d .. %d \n", 
	  	$counter_tag , $device_ID, $min, $max);          	
          next COUNTER ;
      }
      debug_print (3, join (' : ', @floats), "\n");
    
      # now backref'ing ... back down the pada tree ... OMG
      my $i = -1;
      foreach my $parno ( $min .. $max ) {
	      $i++;
	      debug_print (5, "$parno -> $i ") ;
	      my $this_tag = $SDM_tags_by_parno{  $parno};
	      next unless (defined $this_tag)  ;
	      debug_print (5, "$parno -> $i => $this_tag ");
	      $valhash{  $this_tag }->{ 'val' } = $floats [ $i ]
      }
      debug_print (5, "\n");
      # die " ==== healing - not yet ~~~~+~~";

  } # foreach my $slk (@selectors) {

  # --------- values per counter successfully retrieved
  
  if ( $Debug >=5 ) { print(  Data::Dumper->Dump (
	[ \$counter_ptr ,  \%valhash ],  
	[ qw(*counter_ptr   *valhash ) ] ) 
  	);
  }

  # loop over rrds
  foreach my $rrd_tag ( @{$counter_ptr->{ rrds }} ) {  
    debug_printf (4, "counter %s -> rrd %s \n" , $counter_tag, $rrd_tag );
    my $rrdfile = sprintf $RRD_sprintf, $RRD_dir, $RRD_prefix, $counter_tag, $rrd_tag;
    debug_print (2, $rrdfile , "\n");

    my $rrd_dhp = $RRD_definitions{$rrd_tag} ;
    my @rrd_fields  = @{$rrd_dhp->{ fields    }} ;
    my $rrd_tpl = join ( ':', @rrd_fields);
    debug_print(3, $rrd_tpl , "\n");

    my $valstr ='N' ;
    my $check_all_empty = 0 ;
    foreach my $rrd_field (@rrd_fields) {
      $valstr .= ':';	    
      my $val = $valhash{ $rrd_field }->{ 'val' } ;
      if (defined ($val) and ($val ne '')) {
        $valstr .= $val ;
	$check_all_empty ||= 1;
      }

    }

    unless ( $check_all_empty ) { 
      debug_printf (1 ,"empty data set at counter %s -> rrd %s \n" , $counter_tag, $rrd_tag );
      debug_printf (2, "%s\n%s\n",  $rrd_tpl , $valstr );
      if ( $Debug >=3)  { print (3 , Data::Dumper->Dump ([ \$counter_ptr  ],[ qw(*counter_ptr    ) ] ) ) ; }
      # die "DEBUG ---- empty data set ";
      next COUNTER ;
    }

    # print $valstr , "\n";
    RRDs::update($rrdfile, '--template', $rrd_tpl, $valstr);
    if ( RRDs::error ) {
      debug_printf (2, "error updating RRD: %s \n" , RRDs::error ) ;
    } else {
      debug_print(4, "rrd update succesful\n");
    }
  }

  # this is just for good feeling... 
  usleep 1e2 ;
} # foreach my $counter_tag (@counter_subset)

# sleep 5 ;

my $now = Time::HiRes::time();
my $sleep = $nextrun - $now ;
debug_printf (2, "\tcyclesleeper: lastrun=%.2f, nextrun=%.2f, now=%.2f, sleep=%.2f \n", 
	$lastrun, $nextrun , $now , $sleep );

# this one accepts fractional seconds 
# Time::HiRes::sleep( $sleep  ); 

goto HEAD_OF_MAIN_LOOP ;

# should never be here.... so no need to clean up?


exit;

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


# implement SDM / modbus protocol syntax
# return ()  on failure
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

# parse SDM response, 
# @floats = SDM_parse_response ($response, $device_ID, $n_regs)
sub SDM_parse_response {
  my ($response, $device_ID, $n_regs) = @_ ;   

  unless (defined $response) {
	  debug_printf(2, "low level read timeout");
	  return ();
  }

  return () unless ( $#_ == 2 );
  my @rsp = string2array ($response);
  # print debug_hexdump( \@rsp) , "\n";

  # last 2 bytes is crc, everything else goes into CRC check
  my $crc_hi = pop @rsp; # poping from the end, crc is lo byte first order
  my $crc_lo = pop @rsp; 
  # pop @rsp;
  my @digest = modbusCRC ( \@rsp );
  #printf ("digest LSB=0x%0x HSB=0x%0x , crc HSB=0x%0x LSB=0x%0x \n", 
  #	  @digest, $crc_hi , $crc_lo );
  unless ( $digest[1] == $crc_hi and $digest[0] == $crc_lo )  	{ 
	  debug_printf( 5, "digest LSB=0x%0x HSB=0x%0x , crc HSB=0x%0x LSB=0x%0x \n",
		@digest, $crc_hi , $crc_lo );
	  debug_printf( 3, "SDM response crc mismatch" ); 
  }

  # 3 bytes, $n_regs x 4-bit unsigned (don't unpack let decode them), H4 aka 16 bit crc at tha end
  # see https://perldoc.perl.org/functions/pack .... n or S 
  my @unpacked = unpack ( 'C' x 3 . 'N' x $n_regs . 'n' , $response ); 

  my $u_len = scalar @unpacked ;
  # return undef if scalar @unpacked < $n_regs + 4;
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

  # printf "n-regs=%d sc-unp=%d, sc-fl=%d, did=0x%02x cmd=0x%02x len=%d r-crc=0x%04x digHSB=%02x digLSB=%02x \n ",
  #     $n_regs, $u_len , scalar @floats , $r_did, $r_cmd , $r_len, $r_crc,  @digest, ;
  # todo OK: don't die - if happens (shit) return undef;
  return ( @floats) ;
}


# query_socket
#
# ~~~~~~~~~~~~~~~~ perform physical socket queries ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# todo OK?:  errorr checking  with retry and timeouts
#
# returns answer string or undef upon failure
# $response = query_socket ( $sock, $querystring, $expected_bytes , [ $retries , [ $wait_us ]] )
#

sub query_socket {
  my ($sock, $qry, $nexp, $nrtry, $w_us) = @_ ; 
  # print $sock $qry ; 
  
  # hadr overwrite TODO defaults?
  # 1 sec dumb wait runs nice for hours
  # 0.1 sec runs OK for some minutes only
  $nrtry = 20;
  $w_us = 2e4;

  # my $buf;

  # pull off all garbage from the line
  print "~~~~~~~~~~~~~~~~ enter query_socket for $nexp bytes ~~~~~~~~~~~~~ \n";
  for ( 0 .. $nrtry ) {
    my $buf;
    my $rv = sysread ( $sock, $buf,  1024 );

    # https://perldoc.perl.org/functions/sysread
    # http://man.he.net/man2/read
     
    # TODO die "error in cleanup reading from socket : $!" unless (defined $rv) ;
    
    unless ( $rv ) {
	    print "line clean at read No $_ \n";
	    last;
    } else {
	    printf("pulled garbage from line - read No %d - buf: %s \n", $_, 
	    	debug_str_hexdump($buf) ) ;
    }
    usleep ( $w_us );
  }

  syswrite $sock, $qry ;
  # $sock->send($qry);
  printf(' ------ completed $sock->send($qry) , $qry=%s' . "\n", debug_str_hexdump($qry) ) ;


  usleep ($w_us * 1) ; # TODO increase after test to reasonable wait time
  
  
  # usually one shot is OK, but when the line goes out of sync, retries may help

  # my $rc = 0;
  my $response = "";
  my $wantb = $nexp;
  for ( 0 ..  $nrtry) {
    my $rv = sysread ( $sock, $response, $wantb , length ($response) ); # TODO will negative offset work?
    # die "error in regular reading from socket : $!" unless (defined $rv) ;

    if ( $rv ) {
	    $wantb = $nexp - length ($response) ;
	    unless ($wantb) {
		    # exactly 0 bytes to expect - we have $nrtry bytes and hope the best
		    printf("succesful read %d bytes - read No %d : %s \n", $nexp, $_,
		    	debug_str_hexdump($response) ) ;
		    print "~~ === ~~~~~~~~ regular query exit ~~~~~~~~~~ \n";
		    return $response;

	    } elsif ($wantb < 0)  {
		    # we have already overrun and switch to garbage mode
		    printf("overrun read %d bytes - read No %d : %s \n", $rv, $_,
			    debug_str_hexdump($response) ) ;
		    #  nevertheless continue reading to pre-clean line  TODO - really?
		    # return undef ;
		    $wantb = 1024;
		    next; 
	    }
    # $wantb > 0 ; i.e. still bytes missing
    printf("\t- partial read %d / %d bytes - read No %d : %s \n", 
	    $rv, length ($response) ,  $_,
	    debug_str_hexdump($response) ) ;
    # printf( "\t--- acc resp has %d bytes:  %s\n",  length ($response) ,
    # 	    debug_str_hexdump( $response) )  ;
    }
    # we may be here either after partial, overrun or empty read

    # ~~~~~~~~~~~~~~~~~~~~~~
    usleep ( $w_us );
  }
  # time out  while reading if we made it until here
  printf("read timed out after %d loops of %d µs \n", $nrtry, $w_us ) ;

  return undef ;  
}

# ~~~~~~~~~~~~~~~ end of line related stuff ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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

# variant receing and returning string, no fork
sub debug_str_hexdump {
  my $str = shift ;
  my @bytes = map (  sprintf ( "%02x", ord($_) ) , split ("", $str));
  return join ( ':'  ,  @bytes );
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


