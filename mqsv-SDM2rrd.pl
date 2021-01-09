#!/usr/bin/perl
#
# companion to infini-SDM-MODBUS-sniffer.pl
# reads the counter values from message queue and stores them into approriate rrds
# 
# boilerplating: 
# OK - this started as a copy of mqsv-test-client.pl
# OK - will then take the counter related config from infini-SDM-MODBUS-sniffer.pl
# OK - and load in all the counter config from infini-SDM-precook.pl
# - and resemble the data conversion towards rrd from USR-SDM-Poller.pl
#
use strict;
use warnings;

use Data::Dumper ;

use Time::HiRes () ;
use Digest::CRC ;
use POSIX qw (floor);

use IPC::SysV qw(IPC_PRIVATE S_IRUSR S_IWUSR ftok IPC_CREAT IPC_NOWAIT );
use IPC::Msg();
use Cwd qw( realpath );

use RRDs();

# helper to extract the counter configuration
my $precooker = "./infini-SDM-precook.pl";
my $startseq =  array2string(  map  hex, qw( 01 04   00 34  00 02  30 05)  );

our $Debug = 0; 

my @counter_tags = qw ( mains mains_d  );

my $mq_ref = "./message_queue.kilroy" ;
my $mq_mtype = 1;


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

# die "######### DEBUG ########";

if ($Debug >=999) {
  debug_print ( 3,  Data::Dumper->Dump (
	[ \@SDM_regs , \%SDM_reg_by_tag , \%SDM_selectors , \@all_selectors , \%Counterlist  ] ,
	[ qw(*SDM_regs  *SDM_reg_by_tag   *SDM_selectors  *all_selectors       *Counterlist ) ]  )
  );
}
# die "######### DEBUG ########";


# do we need to read this in ? - just busy copying it's code over....

my @precooked = split ("\n",`$precooker`);
my @pre_grepped = grep { ! /^#\s.*/ } @precooked ;

my @requests = ( $startseq ) ; # this is our number 0 req def

foreach my $l  (@pre_grepped) {
  my $rq;	
  foreach ( split (':', $l) ) {
	  $rq .= chr hex $_ ;
  }
  push @requests, $rq;
}

if ($Debug >=999) {
  printf "startseq: %s\nstructure of config reads;\n", debug_str_hexdump($startseq);
  print Dumper (\@precooked , \@pre_grepped  );
  foreach (@requests) { print debug_str_hexdump($_), "\n" ; }
}

#----------------------
# build a hash structure to store(?)/index our data received
# $wayback{ 'query-tag' }->{ 'time' }->values[]
#                           +-some-indices-let's see.... 
#
#  %wayback = (
#       '_0034:0002' => {
#           'qry_tag'   => '_0034:0002',
#           'reg_start' => 52, 'reg_num'   => 2,
#           'param_min' => 27, 'param_max' => 27,
#           'val_tags'  => [ 'Ptot'  ],
#                       },  
#       '_0156:0016' => { .....



my %wayback ;

foreach my $rq (@requests) {
	# my @byte_str = split ';' , $rq;
	# print Dumper (\@byte_str); 
	my ($ID, $x_04, $reg_start, $reg_num, $crc) = unpack ( 'CCnnn' , $rq); 
	
	# my $qry_tag = sprintf ("_%04x:%04x", $reg_start, $reg_num);
	my $param_min = $reg_start/2 +1;
	my $param_max = $param_min -1 + $reg_num/2;
	
	my $qry_tag =  debug_str_hexdump($rq);
	print debug_str_hexdump($rq), "\n" ;
	printf("ID=0x%02x cmd=0x%02x r-start=0x%04x n-reg=0x%04x crc=0x%04x - query-tag= '%s'", 
		$ID, $x_04, $reg_start, $reg_num, $crc, $qry_tag );
	printf(" params min=%d max=%d\n", $param_min , $param_max );

	my @val_tags =();
	for ($param_min .. $param_max) {
		$val_tags[$_ - $param_min ] =$SDM_tags_by_parno{ $_ } || '';
	}	

	my %rqdef = (reg_start=> $reg_start,  reg_num=>  $reg_num,  qry_tag=> $qry_tag ,
		val_tags => \@val_tags , param_min => $param_min,  param_max => $param_max);
	$wayback{ $qry_tag } = \%rqdef;
}


$Debug=5;
print Data::Dumper->Dump ( [ \%wayback ] , [ qw( *wayback) ]  );

print "===================================== setup done =========================== \n";

# die "######### DEBUG ########";
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# open message queue ~~~~~~~~~~~~~~~

# `touch $mq_ref` ; # make sure file exists
my $our_ftok = ftok (realpath ($mq_ref)) ;

# my $MQ  = IPC::Msg->new($our_ftok     ,   S_IWUSR | S_IRUSR |  IPC_CREAT )

my $MQ  = IPC::Msg->new($our_ftok     ,    S_IRUSR | S_IWUSR |  IPC_CREAT   )
	or die sprintf ( "cant create mq using token >0x%08x< ", $our_ftok  );

print " --- message queue open --- \n";

my $cnt =1;
my %cache=();
while (1) {

  my $buf;
  # $mq_my->rcv($buf, 1024, 1 , IPC_NOWAIT  );

  $MQ->rcv($buf, 1024, $mq_mtype);
  # print $buf , "\n" if $buf  ;

  my ($mq_qa, $mq_rq, $starttime , $data_hr) = split ( '\|'  , $buf);
  my @datary =  map (hex,  split ('\:', $data_hr) );
 
  printf ("type=%s, no=%d, time=%014d, data (len=%d): %s  \n", $mq_qa, $mq_rq, $starttime , scalar @datary ,  $data_hr  );
  # print "back-test  ",  , "\n"; 
  # print Data::Dumper->Dump ( [ \@datary ] , [ qw( *datary) ]  );

  $cache{ sprintf("%1s:%1d", $mq_qa, $mq_rq)  } = { last => $starttime, };
  if ($mq_qa eq 'Q')  {
	  $cache{ sprintf("%1s:%1d", $mq_qa, $mq_rq  ) } = { tag => $data_hr };
  } elsif ($mq_qa eq 'R')   {
  	$cache{ sprintf("%1s:%1d:%014d", $mq_qa, $mq_rq , $starttime ) } = { data => \@datary };
  } else {
	die " illegal data type token - hang on, how did I come here??? ";
  }

  print Data::Dumper->Dump ( [ \%cache ] , [  qw ( *cache) ] );
  # sleep ;
  $cnt++;

  # what can we do?
  # if 'R:0'->last ....  and 'Q:0'->tag=> ... process R:0:{time} -> data .... cleanup
  # if R:1 & R:2 & R:3 ... & ... data ... processs... otherstuff..... cleanup
  # if we have more than whatever (20 ?) records in %cache we may die
  if ( $cache{ 'R:0' } and $cache{ 'Q:0' } ) {
	  # we have all we need - ptot, times , definitions
	   print " we hit a ptot case\n";
	# TODO what ist to be done
  } 

  # this is a bit crude, assumes we have on ptot in $requests[0] and sth like 1..3 in the rest
  # push perl at its PERLies ;-}
  # loop over indexes of requests (but the first aka [0]) , count the hits of R and Q labels, 
  # 	and if there are >= 6 we might have a complete data set
  if ( (scalar ( grep { ( $cache{ 'R:'.$_  } and $cache{ 'Q:'.$_ } ) } (0 .. $#requests) ) )  >= $#requests ) {
	  # die " we hit a all other counter case";
	  # TODO what ist to be done
	  # $counter_tags[0] might tell us what exactly
	  # we want to do a rrdupdate, so we need
	  # - the correct rrd name
	  # - the value list
	  # - the values
	  #
	  # try: 
	  # - merge known values
	  # - %Counterlist->{ rrds }[0] --- -> rrd database name
	  # - %RRD_definitions
	  my $counter = $counter_tags[1];
	  my @rrds = @{$Counterlist{ $counter }->{ rrds }} ;
	  print "counter: $counter, rrds: ", join (',', @rrds) , "\n";
	  for my $rrd_tag (@rrds) {
		  my @fields =  @{$RRD_definitions{ $rrd_tag   }->{ fields } };
		  print "fields of $rrd_tag:" , join (',', @fields ) , "\n"; 
	  }
	# get the values to the tags
	my $foo =  sdm_evaluate ( \%wayback, \%cache );
 

  

	  die " ~~~~~~~~~~~~~~~ we hit a all other counter case ~~~~~~~~~~~~~~~~~~~~~~+" ;

  }

  if (scalar keys %cache >20 ) {
	die "looks like our cache is clobbered with BS stuff .... ";
	# TODO what ist to be done

  }
}

exit 1;

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# hang on, what's going on here???
#  sdm_evaluate ( \%wayback, \%cache )  
sub sdm_evaluate  {
  my ($wb, $ch) = @_ ;
  print Data::Dumper->Dump ( [ $wb, $ch] , [ qw(  *wb *ch ) ] );
  die "debug in -------------- sub sdm_evaluate -----------";
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
