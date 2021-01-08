#/bin/bash
# DEVICE="-F $1"
# DEVICE="-F /dev/ttyChargery"
DEVPATH=~/infini/dev_infini_modbus
DEVICE="-F $DEVPATH"
echo $DEVICE
# exit
stty $DEVICE -a
echo "------ apply changes -----"
sleep 1
stty $DEVICE 19200 raw
stty $DEVICE time 50 
stty $DEVICE -echo -echoe -echok -echoctl -echoke
echo "------ done -------"
stty $DEVICE -a
sleep 1
echo "----- simple output -----"
stty $DEVICE
