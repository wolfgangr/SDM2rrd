#!/bin/bash

# systemd starter script

UPDLOG='/var/log/wrosner/counter_USR-SDM-poll.log'


SCRIPTDIR=`dirname "$0"`
# echo $SCRIPTDIR
cd $SCRIPTDIR
cd ..

# spawn our associated babysitter
./watchdogUSR_systemd.pl &

# not sure what environment we get from systemd
# source /etc/profile
# source ~/.profile
# echo $PATH
# pwd
# launch the real thing
./USR-SDM-Poller.pl 2>> $UPDLOG 1>> /dev/null   &


# don' return to systemd, this breaks `notify` setting 
sleep infinity

