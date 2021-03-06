# Where work is done

This explains the scrits running 24/7 either as cron jobs or continously.

## `USR-SDM-Poller.pl`
polls 6 counters on the USR gadget.  
USR access is configured in the head of the script, since there is no need to sync that with other places - yet.   
Beware that USR does **not translate** MODBUS-RTU to MODBUS-TCP, **just wraps** it into TCP transfer.  
And tcp securing ends at the USR - not at the counter. Shitt may happen at that last meters of twisted wires.  

So I's up to us to implement
* CRC management both on query and upon checking responses
* handle bus errors, timeout, collisions etc.

I started of with syncronous reading, but got read hangs after some minutes ... hours.  
Asynchronous reading is more work, but quite stable now.  

`USR-SDM-Poller.pl` runs continously to avoid PERL startup overhead.  
rtfS:
```
my $interval = 15 ; # seconds between runs
my $interval_shift = 7 ; # seconds shift from even interval
```
... yields runs at seconds 7, 22, 37, 52 counted from start of the minute. 
This turned out to deliver quite stable reading.  
At an rrd step rate of 30 s = lowest RRA heartbeat this means 2 datapoints being merged into one rrd value.  
Higher rates tend to overload the MODBUS, as it seems. Be aware that TCP transmission control ends at the USR. There is no control layer on the MODBUS section. However, there is random time lag introduced by the network. Thus, nasty things may happen. CRC check helps a lot.  

There are still spikes in the data, when shitt is happening. I think that I may indroduce undef into my data when collecting multiple query bursts and and get one miss. PERL may be mis-dwimminessing those to zeros, rrd ... or what --- maybe --- dont know....TODO



### watchdog.sh

`cron`ed at intervals to check and maybe resurrect the poller.
relies on `rrdtest.pl` as a helper ... to be documented ....


## infini-SDM-MODBUS-sniffer.pl
The counter at the mains electicity grid connection is a bit more tricky. I have to **share the MODBUS** connection of ot with my infini battery inverter.  
Why?  
The ifnini is supposed to charge a battery, when photovoltaic production exceeds local energy consumption, and feed it back the other way round.
The infini is equipped with a modbus card to communicate with the SDM conter at mains connection.  
It polls total power once a second from the SDM. I can passivly sniff this, but this way, I only get total power - nothing else.  

There are 'man in the middle' hacks out there for this setting.  
I'll try a different approach:  
  
Good news: the **Modbus** protocol has **"multi master"** capability.  
So I may inject additional commands to the bus, requesting other registers from the SDM.  
It's my responsibility to avoid collisons. It's not ethernet, it's not in the protocol.  
So what I do is:  
* read a message from the bus
* start a watch, if it is a infini total-Power query
* read the SDM answer and safe it for processing
* wait 0.1 s and issue our own query
* wait another 0.3 s before we ...
* reading the answer to our own query and safe it for processing

First experimental tests indicate that with these settings, neiter the infini nor my own queries suffer from significant bus garbage. At least my data are fine, and the infini display shows no sign of transmission errors. Life production tests are still outstanding.  

To further reduce the risk of MODBUS collison, I leave some seconds untouched. The details are configured similiar to  `USR-SDM-Poller.pl`:
```
# parameter for limiting bus load
my $interval = 15 ; # seconds between additional query runs
my $interval_shift = 7 ; # seconds shift from even interval modulos
my $inter_query_stepping = 3 ; # how many native qry occasions to skip befor inserting extra qry
```
Translates to
* starting at second No 7, we inject our first mutimaster query
* at second No 10, 13, 16 we inject the other mutimaster queries
* at second 15+7 = 22 we start again

To keep the multimaster part small and fast, downstream data processing is handed over to a distinct process, communicating by a sysv message queue.
I could not get Posix MQ to work under PERL- wihtout leaving debian package boundaries. sorry ....  
  
SysV message queue requires a file handle to generate unique key, shared by both partners on the line. I simply touch some `message_queue.kilroy` file. As long as nobody removes this, the message queue key stays constant.  
At earlier trials I used the scripts own file handle. I had to learn that vi obviously renames files back and forward with their backup counterpart. This cuts mapping of filehandle with file name, sadly.




### infini-SDM-precook.pl

simply dumps to stdout the MODBUS query derived from confguration.  
PERL syntax, so only the hex coded lines are read.  
`infini-SDM-MODBUS-sniffer.pl` reads this using backtick syntax  
`my @precooked = split ("\n",``$precooker``);`  
The idea was to keep elaborated config processing and modbus protocol handling out of `infini-SDM-MODBUS-sniffer.pl` code.  
was this a good idea?  
```
# details: ID=1, bus=MODBUS-hack 
#        register selection min=1, max=38 
#        -> U1:U2:U3:I1:I2:I3:P1:P2:P3:VAr1:VAr2:VAr3:Ptot:VArtot:F:E_imp:E_exp
01:04:00:00:00:4c:f1:ff
#        register selection min=118, max=126 
#        -> thdU1:thdU2:thdU3:thdI1:thdI2:thdI3:thdUtot:thdItot
01:04:00:ea:00:12:51:f3
#        register selection min=172, max=182 
#        -> E_sld:VAr_sld:E1_imp:E2_imp:E3_imp:E1_exp:E2_exp:E3_exp:E1_sld:E2_sld:E3_sld
01:04:01:56:00:16:90:28
```

### `mqsv-test-client.pl`

is just reading from the message queue for debug timing, message format, bus trafic etc...  
It's not reuqired for 24/7 production.


### `mqsv-SDM2rrd.pl`  
Is the productive consumer of the mq stream.  
It's derived from `USR-SDM-Poller.pl` and shares quite some code.  
Most of it by simple cut'n paste. For sure there is some potential for proper modularisation.


### `watchdog_mqsv.sh`
#### `mqsv-cleanup.pl`

Check the rrds fed by the sniffer / mq machine and resurrect the whole thing in case of shitt going to happen.


## `sync-counter-rrd-to-SQL.pl`
Updates a subset of rrd data to mysql.  
Supposedly called on intervals as a cron job.  

My databases have two time columns:
- `time`, when the values were collected
- `update_time`, when the values are written to the SQL  
`time` is the primary index.  
This way, datasets can be loaded repeatedly, the machine keeps them unique automagically.

```
CREATE TABLE `mySDM_mains_d_elbasics` (
  `time` datetime NOT NULL,
  `P1` float DEFAULT NULL,
  `P2` float DEFAULT NULL,
  `P3` float DEFAULT NULL,
  `update_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' ON UPDATE current_timestamp(),
  PRIMARY KEY (`time`)
) ENGINE=MyISAM DEFAULT CHARSET=ascii ;
```
I started with a simple bash approach of rrd2csv.pl > mysqlimport calls.  
Sadly, this was broken, wenn I switched to configurable subsets of data fields.  
Reason: I had to switch to explicit column naming syntax using `--columns=...` option.  
Before, there was automagic NULL loaded into `update_time`, because the csv had one column less than the database expects.  
Beore I started fiddling with awk or sed, I decided to use perl for DB update.  
Thus I hit some cron issues, but could solve them.  





## Data flow
see[data_flow.md](data_flow.md)





