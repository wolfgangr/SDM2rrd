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

our $Debug = 5; 

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


if ($Debug >=5) {
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

if ($Debug >=5) {
  printf "startseq: %s\nstructure of config reads;\n", debug_str_hexdump($startseq);
  print Dumper (\@precooked , \@pre_grepped  );
  foreach (@requests) { print debug_str_hexdump($_), "\n" ; }
}

#----------------------
# build a hash structure to store(?)/index our data received
# $input_cache{ 'query-tag' }->{ 'time' }->values[]
#                           +-some-indices-let's see.... 
#
#  %input_cache = (
#       '_0034:0002' => {
#           'qry_tag'   => '_0034:0002',
#           'reg_start' => 52, 'reg_num'   => 2,
#           'param_min' => 27, 'param_max' => 27,
#           'val_tags'  => [ 'Ptot'  ],
#                       },  
#       '_0156:0016' => { .....



my %input_cache ;

foreach my $rq (@requests) {
	# my @byte_str = split ';' , $rq;
	# print Dumper (\@byte_str); 
	my ($ID, $x_04, $reg_start, $reg_num, $crc) = unpack ( 'CCnnn' , $rq); 
	
	my $qry_tag = sprintf ("_%04x:%04x", $reg_start, $reg_num);
	my $param_min = $reg_start/2 +1;
	my $param_max = $param_min -1 + $reg_num/2;
	
	# my $qry_tag =  debug_str_hexdump($rq);
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
	$input_cache{ $qry_tag } = \%rqdef;
}

print Data::Dumper->Dump ( [ \%input_cache ] , [ qw( *input_cache) ]  );

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
while (1) {

  my $buf;
  # $mq_my->rcv($buf, 1024, 1 , IPC_NOWAIT  );

  $MQ->rcv($buf, 1024, $mq_mtype);
  print $buf , "\n" if $buf  ;

  my ($mq_qa, $mq_rq, $starttime , $data_hr) = split ( '\|'  , $buf);
  my @datary =  split ('\:', $data_hr);
  printf ("type=%s, no=%d, time=%014d, data (len=%d): %s  \n", $mq_qa, $mq_rq, $starttime , scalar @datary ,  $data_hr  );


  # sleep ;
  $cnt++;


}

exit 1;

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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
