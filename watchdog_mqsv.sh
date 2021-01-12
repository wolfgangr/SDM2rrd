#!/bin/bash

cd ~wrosner/eastron_SDM/mySDMpoller
PROCESS_S=infini-SDM-MODBUS-sniffer.pl
PROCESS_R=mqsv-SDM2rrd.pl

WATCHED='rrd/mySDM_mains_*.rrd'

# STARTER="./$PROCESS"
#PRESTARTER='./setstty-RS485.sh' 
# RESTARTER=
# CALLER='/usr/bin/perl'
LOGFILE='/var/log/wrosner/watchdog_MM-counter.log'
UPDLOG='/var/log/wrosner/counter_Modbus.log'

# uncomment this 2 line for debug
echo -n "infini MODBUS multimaster watchdog entered " >> $LOGFILE
date >> $LOGFILE


# exit - nothing to do if rrdtest reports success
./rrdtest.pl $WATCHED   2>> $LOGFILE | tail -n1 >> $LOGFILE 
STATUS=${PIPESTATUS[0]}
if [ $STATUS -eq 0 ] ; then
	exit
fi


echo -n "Modbus MultiMaster watchdog triggered at " >> $LOGFILE
date >> $LOGFILE

# ps ax | grep "./$PROCESS" | grep '/usr/bin/perl' >> $LOGFILE

# first try a soft kill:
./mqsv-cleanup.pl
# exit

#------------
killall $PROCESS_S  >>  $LOGFILE 2>&1
killall $PROCESS_R  >>  $LOGFILE 2>&1
sleep 5 

killall -9 $PROCESS_S  >> $LOGFILE 2>&1
killall -9 $PROCESS_R  >> $LOGFILE 2>&1
sleep 5

# echo -n "---- restarted at " >> $UPDLOG
# date >> $UPDLOG 
./$PROCESS_R 2>> $UPDLOG 1>> /dev/null   &
sleep 1
./$PROCESS_S 2>> $UPDLOG 1>> /dev/null   &

echo -n "----- done -----  " >> $LOGFILE
date >> $LOGFILE
