#!/bin/bash

cd ~wrosner/eastron_SDM/mySDMpoller
# PROCESS='scheduler.pl'
PROCESS='USR-SDM-Poller.pl'

WATCHED='rrd/mySDM_subs*.rrd'

STARTER="./$PROCESS"
#PRESTARTER='./setstty-RS485.sh' 
RESTARTER=
CALLER='/usr/bin/perl'
LOGFILE='/var/log/wrosner/watchdog_counter.log'
UPDLOG='/var/log/wrosner/counter_USR-SDM-poll.log'

# uncomment this 2 line for debug
# echo -n "chargery rrd watchdog entered " >> $LOGFILE
date >> $LOGFILE


# exit - nothing to do if rrdtest reports success
./rrdtest.pl $WATCHED   2>> $LOGFILE | tail -n1 >> $LOGFILE 
STATUS=${PIPESTATUS[0]}
if [ $STATUS -eq 0 ] ; then
	exit
fi


echo -n "infini rrd watchdog triggered at " >> $LOGFILE
date >> $LOGFILE

ps ax | grep "./$PROCESS" | grep '/usr/bin/perl' >> $LOGFILE

killall $PROCESS  >>  $LOGFILE 2>&1
sleep 5 
killall -9 $PROCESS  >> $LOGFILE 2>&1
sleep 

$PRESTARTER  >> $LOGFILE 2>&1
# echo -n "---- restarted at " >> $UPDLOG
# date >> $UPDLOG 
$STARTER 2>> $UPDLOG 1>> /dev/null   &

echo -n "----- done -----  " >> $LOGFILE
date >> $LOGFILE
