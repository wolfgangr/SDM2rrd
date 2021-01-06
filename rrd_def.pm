use warnings;
use strict;
# use Data::Dumper  qw(Dumper);

# our $Debug ;
# require ('./my_debugs.pl');


# 30s
# 300s = 5m
# 3600s =1h
# 8400s =1d

# this is from infin
# RRA:AVERAGE:0.5:2:86400  \
# RRA:MIN:0.5:60:26000  \
# RRA:MAX:0.5:60:26000  \
# RRA:AVERAGE:0.5:60:26000  \
# RRA:MIN:0.5:720:10000  \
# RRA:MAX:0.5:720:10000  \
# RRA:AVERAGE:0.5:720:10000  \
# RRA:MIN:0.5:17280:22000  \
# RRA:MAX:0.5:17280:22000  \
# RRA:AVERAGE:0.5:17280:22000 

# https://oss.oetiker.ch/rrdtool/doc/rrdcreate.en.html#STEP%2C_HEARTBEAT%2C_and_Rows_As_Durations
#   RRA:AVERAGE:0.5:1s:10d \
#   RRA:AVERAGE:0.5:1m:90d \
#   RRA:AVERAGE:0.5:1h:18M \
#   RRA:AVERAGE:0.5:1d:10y

our %RRD_definitions ;

$RRD_definitions{'totalP'} = {
	fields => [ qw( Ptot ) ], 
	rradef => <<"EOF_TOTALP_RRA",
RRA:AVERAGE:0.5:30s:1m
RRA:AVERAGE:0.5:5m:1y
RRA:MAX:0.5:5m:3m
RRA:AVERAGE:0.5:1h:5y
RRA:MAX:0.5:1h:2y
EOF_TOTALP_RRA
} ;

my $simple_E_rra = <<"EOF_SE_RRA",
RRA:LAST:0.5:30s:1m
RRA:LAST:0.5:5m:3m
RRA:LAST:0.5:1h:1y
RRA:LAST:0.5:1d:5y
EOF_SE_RRA
 ;

$RRD_definitions{'E_bidir'} = {
        fields => [ qw( E1_sld E2_sld E3_sld E_sld E1_imp E2_imp E3_imp E_imp E1_exp E2_exp E3_exp E_exp  ) ] ,
        rradef => $simple_E_rra ,
} ;

$RRD_definitions{'E_unidir'} = {
        fields => [ qw( E1_sld E2_sld E3_sld E_sld ) ] ,
        rradef => $simple_E_rra ,
} ;

$RRD_definitions{'elbasics'} = {
	fields => [ qw(P1 P2 P3 I1 I2 I3 U1 U2 U3 ) ] ,
	rradef => <<"EOF_EB_RRA",
RRA:AVERAGE:0.5:30s:1m
RRA:AVERAGE:0.5:5m:3m
RRA:MAX:0.5:5m:1m
RRA:AVERAGE:0.5:1h:2y
RRA:MAX:0.5:1h:6m
EOF_EB_RRA
} ; 


$RRD_definitions{'elquality'} = {
	fields => [ qw(  F   VAr1 VAr2 VAr3 VArtot   thdI1 thdI2 thdI3 thdItot   thdU1 thdU2 thdU3 thdUtot )],
	rradef => <<"EOF_EQ_RRA",
RRA:AVERAGE:0.5:30s:10d
RRA:AVERAGE:0.5:5m:1m
RRA:AVERAGE:0.5:1h:6m
RRA:MAX:0.5:1h:6m
EOF_EQ_RRA
} ;



# defaults
# step = 5
# hb =30
# rra standard
