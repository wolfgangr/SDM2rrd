#!/bin/bash

# systemd starter script

UPDLOG='/var/log/wrosner/counter_Modbus.log'
DEVICE='/home/wrosner/infini/dev_infini_modbus/';

SCRIPTDIR=`dirname "$0"`
# echo $SCRIPTDIR
cd $SCRIPTDIR



# like unplugging / replugging
./reset_ttyUSB.pl $DEVICE
sleep 2

cd ..

./setstty-RS485.sh  >> $UPDLOG

# spawn our associated babysitter
./watchdogInfini_systemd.pl &





# infini-SDM-MODBUS-sniffer.pl
./mqsv-SDM2rrd.pl 2>> $UPDLOG 1>> /dev/null   &
# ./mqsv-SDM2rrd.pl & 
sleep 2

./infini-SDM-MODBUS-sniffer.pl 2>> $UPDLOG 1>> /dev/null   
# ./infini-SDM-MODBUS-sniffer.pl


# don' return to systemd, this breaks `notify` setting 
# sleep infinity
exit 1
