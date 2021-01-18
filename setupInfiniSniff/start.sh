#!/bin/bash

# systemd starter script

UPDLOG='/var/log/wrosner/counter_Modbus.log'


SCRIPTDIR=`dirname "$0"`
# echo $SCRIPTDIR
cd $SCRIPTDIR
cd ..

# spawn our associated babysitter
./watchdogInfini_systemd.pl &

# not sure what environment we get from systemd
# source /etc/profile
# source ~/.profile
# echo $PATH
# pwd
# launch the real thing
# ./USR-SDM-Poller.pl > /dev/null

# we have a 2 staged setting, connected by message queue
# try to give the consumer time to pull off stuff of the queue  if there
# infini-SDM-MODBUS-sniffer.pl
./mqsv-SDM2rrd.pl 2>> $UPDLOG 1>> /dev/null   &
# ./mqsv-SDM2rrd.pl & 
sleep 2

./infini-SDM-MODBUS-sniffer.pl 2>> $UPDLOG 1>> /dev/null   
# ./infini-SDM-MODBUS-sniffer.pl


# don' return to systemd, this breaks `notify` setting 
# sleep infinity
exit 1
