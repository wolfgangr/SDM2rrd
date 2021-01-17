# ressource usage

I have it running togehter with a couple of similiar projects on a 10 year old 'thin client' laptop style hardware single core 1200 MHz AMD G-T44R Processor and 4GB RAM. Mass storage is a 64 GB SSD. rrd as configured need 311 MB - so this is luxury.
Nevertheless, it's wise to use df and du commands and maybe a calculator while playing with rrd configurations.

There is a 64-bit debian 10.7 on the box.
Completely headless except for bios configuration. 'Thin server', so to say.
All PERL modules used are from debian main repo, no backports, no CPAN, no custom build.

So I guess a raspberry could do the job as well, but I haven't tried.
Personally, I don't like the idea of runnig rrd on SD-cards. Don't like mass storage, network and peripheral access all sharing the same USB Bus. File systems for 24/7 operations mounted over fragile USB plugs. But all that may be a matter of taste.

## timing issues

## system load

CPU load is << 5 % during polling and goes close to 100 % for a second or so when performing large requestes as in producing charts or preparing SQL database uploads.
Both rrd and PERL hash arithmetics appears to be implemented quite efficiently at run time.
However, there is quite some penalty on PERL startup. I think that many included libraries come with quite some penalty regarding this. So it's not wise to cron start PERL at minute intervals. I prefer running demons with internal 'sleep' commands. In my development process, this cutted down system load by 95 % and more.


## disk space

disk space is determined by rrd files. rtfM over there how to calculate.  
Of course, long time database sync at fine time resolution may be even worse.  
There are temporary csv files generated. So, be prudent.  

Be aware that rrd statically reserves all disk space required to cover the configured time frame.  
So there is a **tradeoff between temporal resolution, time coverage and disk space**.  
My current config usses 311 MByte. Still OK on a 64 GB SSD.  

Just an example: consider this 2.somewhat MB file 
`-rw-r--r-- 1 myuser myuser  2265096 Jan 17 14:05 mySDM_subs1_totalP.rrd`
is composed of
```
...:~/eastron_SDM/mySDMpoller$ rrdtool info rrd/mySDM_subs1_totalP.rrd | grep step
step = 30
...:~/easton_SDM/mySDMpoller$ rrdtool info rrd/mySDM_subs1_totalP.rrd | grep rows
rra[0].rows = 89280
rra[1].rows = 105408
rra[2].rows = 26784
rra[3].rows = 43920
rra[4].rows = 17568
...:~/eastron_SDM/mySDMpoller$ rrdtool info rrd/mySDM_subs1_totalP.rrd | grep pdp_per_row
rra[0].pdp_per_row = 1
rra[1].pdp_per_row = 10
rra[2].pdp_per_row = 10
rra[3].pdp_per_row = 120
rra[4].pdp_per_row = 120
```
which derives from this stanza in `rrd_def.pm`
```
RA:AVERAGE:0.5:30s:1M
RRA:AVERAGE:0.5:5m:1y
RRA:MAX:0.5:5m:3M
RRA:AVERAGE:0.5:1h:5y
RRA:MAX:0.5:1h:2y
```
let's calculate: 
* `step = 30` = 1 'primary data point' aka `pdp` covers 30 s
* `rra[0].pdp_per_row = 1` means 1 pdp = 30 s covered by a single rrd set
* ... x 89,280 = 2,677,200 seconds coverage
* ... / 3600 s = 743.7 hr
* ... / 24 h ~ 31 d - 
* ... as was requested by `RA:AVERAGE:0.5:30s:1M`
  
simliarly: 
* `RRA:AVERAGE:0.5:5m:1y` maps to
* `rra[1].rows = 105408` x `rra[1].pdp_per_row = 10` x 30 s (per pdp step) = 31,622,400 s = 366 days

* all rra row numbers add up to 89,280 + 105,408 + 26,784 + 43,920 + 17,568 = 282,960
* rrd is hard coded to use 64 bit numbers (Don't ask me why...) = 8 byte
* .... x 8 = 2,263,680 byte
* which explains more than 99 % of rrd file size
* beware: this is a rrd with one field aka `DS` aka data source only. Disk space multiplies by the number of fields!


```
RRA:AVERAGE:0.3:1s:1w
RRA:AVERAGE:0.5:30s:1M
RRA:AVERAGE:0.5:5m:1y
RRA:MAX:0.5:5m:3M
RRA:AVERAGE:0.5:1h:5y
RRA:MAX:0.5:1h:2y
```

```
rra[0].pdp_per_row = 1
rra[1].pdp_per_row = 30
rra[2].pdp_per_row = 300
rra[3].pdp_per_row = 300
rra[4].pdp_per_row = 3600
rra[5].pdp_per_row = 3600
```
