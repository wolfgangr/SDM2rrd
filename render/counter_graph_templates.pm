# here docs for chart templating
#




our $rrd_tpl_mains_stacked = << "EOF_MAINS_STACKED";
  --title=Mains Power stacked \
 --upper-limit=8000 \
 --title=Mains Power stacked \
 --lower-limit=-500 \
 --rigid \
 DEF:b=/home/wrosner/eastron_SDM/mySDMpoller/rrd//mySDM_subs1_totalP.rrd:Ptot:AVERAGE \
 DEF:c=/home/wrosner/eastron_SDM/mySDMpoller/rrd//mySDM_subs2_totalP.rrd:Ptot:AVERAGE \
 DEF:d=/home/wrosner/eastron_SDM/mySDMpoller/rrd//mySDM_subs3_totalP.rrd:Ptot:AVERAGE \
 DEF:e=/home/wrosner/eastron_SDM/mySDMpoller/rrd//mySDM_subs4_totalP.rrd:Ptot:AVERAGE \
 DEF:f=/home/wrosner/eastron_SDM/mySDMpoller/rrd//mySDM_subs5_totalP.rrd:Ptot:AVERAGE \
 DEF:a=/home/wrosner/eastron_SDM/mySDMpoller/rrd//mySDM_mains_totalP_hires.rrd:Ptot:AVERAGE \
 DEF:g=/home/wrosner/eastron_SDM/mySDMpoller/rrd//mySDM_subs6_totalP.rrd:Ptot:AVERAGE \
 CDEF:H=0,g,- \
 AREA:b#FFA500:Whg NEU \
 AREA:c#008000:Whg ALT:STACK \
 AREA:d#800080:KartLg:STACK \
 AREA:e#FFD700:Stall + WS:STACK \
 AREA:f#FF0000:Keller+Hz:STACK \
 AREA:H#00FF00: infini pos:STACK \
 LINE3:a#0000FF:Netzbezug
EOF_MAINS_STACKED



our $rrd_tpl_mains_lined = << "EOF_MAINS_LINED";
 --title=Mains Power sep \
 --lower-limit=0 \
 --rigid \
 --upper-limit=5000 \
 DEF:b=/home/wrosner/eastron_SDM/mySDMpoller/rrd//mySDM_subs1_totalP.rrd:Ptot:AVERAGE \
 DEF:c=/home/wrosner/eastron_SDM/mySDMpoller/rrd//mySDM_subs2_totalP.rrd:Ptot:AVERAGE \
 DEF:d=/home/wrosner/eastron_SDM/mySDMpoller/rrd//mySDM_subs3_totalP.rrd:Ptot:AVERAGE \
 DEF:e=/home/wrosner/eastron_SDM/mySDMpoller/rrd//mySDM_subs4_totalP.rrd:Ptot:AVERAGE \
 DEF:f=/home/wrosner/eastron_SDM/mySDMpoller/rrd//mySDM_subs5_totalP.rrd:Ptot:AVERAGE \
 DEF:g=/home/wrosner/eastron_SDM/mySDMpoller/rrd//mySDM_subs6_totalP.rrd:Ptot:AVERAGE \
 DEF:a=/home/wrosner/eastron_SDM/mySDMpoller/rrd//mySDM_mains_totalP_hires.rrd:Ptot:AVERAGE \
 CDEF:H=0,g,- \
 LINE1:b#FFA500:Whg NEU \
 LINE1:c#008000:Whg Alt \
 LINE1:d#800080:Kar-Lager \
 LINE1:e#FFD700:Stall WS \
 LINE1:f#FF0000:Keller+Hz \
 LINE3:a#0000FF:Netzbezug \
 LINE1:H#00FF00: 
EOF_MAINS_LINED



