# Where work is done

This explains the scrits runnint 24/7 either as cron jobs or continously.

## `USR-SDM-Poller.pl`
polls 6 counters on the USR gadget.  
USR access is configured in the head of the script, since there is no need to sync that with other places - yet.   
Beware that USR does **not translate** MODBUS-RTU to MODBUS-TCP, **just wraps** it into TCP transfer.  

So I's up to us to implement
* CRC management both on query and upon checking responses
* handle bus errors, timeout, collisions etc.

I started of with syncronous reading, but got read hangs after some minutes ... hours.  
Asynchronous reading is more work, but quite stable now.  





infini-SDM-MODBUS-sniffer.pl
infini-SDM-precook.pl
mqsv-cleanup.pl
mqsv-SDM2rrd.pl
mqsv-test-client.pl



sync-counter-rrd-to-SQL.pl
