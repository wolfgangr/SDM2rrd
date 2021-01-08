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




my @precooked = split ("\n",`./infini-SDM-precook.pl`);
my @pre_grepped = grep { ! /^#\s.*/ } @precooked ;
print Dumper (\@precooked , \@pre_grepped);
