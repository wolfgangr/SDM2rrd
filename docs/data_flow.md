# Data flow model


```
+- USR-SDM-Poller.pl <--{[( my LAN ) ]} <-(TCP)- [USR-TCP gadget] mqsv-SDM2rrd.pl <-( Modbus over RS485)- [SDM x 6]
| 
|        +--infini-SDM-MODBUS-sniffer.pl <- USB-serial <- RS485 (infini <- Modbus over RS485-> SDM)
|        |
|       sysV Message queue  ... -> mqsv-test-client.pl -> console debugging
|        |
|        V
|     mqsv-SDM2rrd.pl
|        |
V        V
=============
  PERL RRDs
+----------------------------------+
| set of rrd round robin databases |  <-> console debugging ( rrdtool, rrd2csv.pl, rrdtest.pl ...)
+----------------------------------+
    PERL RRDs 
====================
|         |        |
|         |        V
|         V      drraw -> rrdgraph -> HTML & PNG -> web Browser (experimental rendering)
|        counters.pl   -> rrdgraph -> HTML & PNG -> web Browser (structured time browsing) - ####TODO###
|
V
rrd2csv.pl
    |
    |
    V
sync-counter-rrd-to-SQL.pl -> mysqlimport -> {[( my LAN ) ]} -> MaraiaDB -> Backup

``` 
