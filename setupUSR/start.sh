#!/bin/bash

# systemd starter script

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
./USR-SDM-Poller.pl > /dev/null

# don' return to systemd, this breaks `notify` setting 
