#!/usr/bin/perl
#
# watchdog helper
# if called, it shall
# - indetify our mq
# - kill the writer
# - wait a bit until the queue is clean
# - kill the reader
# - delete the queue
# - fall back to harsh methods of term signals don't work

use strict;
use warnings;

use IPC::SysV qw(IPC_PRIVATE S_IRUSR S_IWUSR ftok IPC_CREAT IPC_NOWAIT );
use IPC::Msg();
use Cwd qw( realpath );
# use Time::HiRes () ;
use Data::Dumper ;

my $mq_ref = "../message_queue.kilroy" ;
my $mq_mtype = 1;

# `touch $mq_ref` ; # make sure file exists
my $our_ftok = ftok (realpath ($mq_ref)) ;

my $MQ  = IPC::Msg->new($our_ftok , 0      )
	or die sprintf ( "cant create mq using token >0x%08x< ", $our_ftok  );

my $stat = $MQ->stat ;

# print Data::Dumper->Dump ( [ \$our_ftok, \$MQ,  \$stat ] , [ qw( *our_ftok *MQ  *stat) ] );

# the writer
my $lspid = $stat->lspid; # the writer
my $lrpid = $stat->lrpid; # the reader
my $qnum =  $stat->qnum ; # 
my $mqid = $MQ->id  ; # the current identifier != ftok 


printf  "going to kill key: 0x%08x, ID=%d, lspid: %d,  lrpid: %d, qnum: %d, \n" , $our_ftok, $mqid , $lspid , $lrpid , $qnum ;

# cave - if there is no lspid or rspid, you kill 0 which is your own process group
kill 'TERM' , $lspid if $lspid  ;
sleep 1;
kill 'TERM' , $lrpid if $lrpid  ;
sleep 1;
print "removing message queue\n";
$MQ->remove ;
print "...done.\n";

# die  "=============== debug =========== ";
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


