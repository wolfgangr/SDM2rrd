#!/usr/bin/perl
#
use strict;
use warnings;

use IPC::SysV qw(IPC_PRIVATE S_IRUSR S_IWUSR ftok IPC_CREAT IPC_NOWAIT );
use IPC::Msg();
use Cwd qw( realpath );
use Time::HiRes () ;

my $mq_ref = "./message_queue.kilroy" ;
my $mq_mtype = 1;

`touch $mq_ref` ; # make sure file exists
my $our_ftok = ftok (realpath ($mq_ref)) ;

my $MQ  = IPC::Msg->new($our_ftok     ,   S_IWUSR | S_IRUSR |  IPC_CREAT )
	or die sprintf ( "cant create mq using token >0x%08x< ", $our_ftok  );



my $cnt =1;
while (1) {
  # rolling ms
  # my $ts = (int (Time::HiRes::time * 1000)) % 0x100000000 ;
  # my $msg = sprintf ("%08x:%08x::GS" , $ftok_my, $ts );
  # print "sending .... ", $msg ;
  # $mq_srv->snd (1, $msg );
  # print " ... done \n";

  # sleep 1;

  my $buf;
  # $mq_my->rcv($buf, 1024, 1 , IPC_NOWAIT  );

  $MQ->rcv($buf, 1024, $mq_mtype);
  print $buf , "\n" if $buf  ;

  # sleep ;
  $cnt++;


}

exit 1;

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


