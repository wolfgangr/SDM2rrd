# Ressource Usage

I have it running togehter with a couple of similiar projects on a 10 year old ' Fujitsu Futro S900 thin client' laptop style hardware. CPU is a single core 1200 MHz AMD G-T44R Processor, and 4GB RAM. Mass storage is a 64 GB SSD.  
  
rrd as configured need 311 MB - so there is still some luxury.  
Nevertheless, it's wise to use df and du commands and maybe a calculator while playing with rrd configurations.

There is a 64-bit debian 10.7 on the box.  
Completely headless except for bios configuration. 'Thin server', so to say.   
All PERL modules used are from debian main repo, no backports, no CPAN, no custom build.  

To my guess, a raspberry could do the job as well, but I haven't tried.  
Personally, I don't like the idea of runnig rrd on SD-cards.  
Don't like mass storage, network and peripheral access all sharing the same USB Bus.  
File systems for 24/7 operations mounted over fragile USB plugs.  
But all that may be a matter of taste.



## system load

CPU load is << 5 % during polling and goes close to 100 % for a second or so when performing large requestes as in producing charts or preparing SQL database uploads.  
Both rrd and PERL hash arithmetics appears to be implemented quite efficiently at run time.  
However, there is quite some penalty on PERL startup.   
I think that many included libraries come with quite some penalty regarding this.  
May be I will drop the option of wolr wide time zone configurability?   

Anyway, it's not wise to cron start PERL at minute intervals.  
I prefer running demons with internal 'sleep' commands.   
In my development process, this cutted down system load by 95 % and more.


## Disk Space

### rrd Databases

disk space is determined by rrd files. rtfM over there how to calculate.  

Be aware that rrd statically reserves all disk space required to cover the configured time frame.  
So there is a **tradeoff between temporal resolution, time coverage and disk space**.  
My current config usses 311 MByte. Still OK on a 64 GB SSD. And there are other projects and furthr plans.   

Just an example: consider this 2.somewhat MB file:   
`-rw-r--r-- 1 myuser myuser  2265096 Jan 17 14:05 mySDM_subs1_totalP.rrd`  
it is composed of
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


another case: `mySDM_mains_totalP_hires.rrd`
Here I capture mains power flow at 1s rate.
What I want to see is how precise the infini is doing its power compensations, hwo it reacts to sudden changes in demand / supply, and how stable the control implementation is there.  
Only one week costs me ~~ 5 MB. But is there any need for archived data of this precision?
```
RRA:AVERAGE:0.3:1s:1w
RRA:AVERAGE:0.5:30s:1M
RRA:AVERAGE:0.5:5m:1y
RRA:MAX:0.5:5m:3M
RRA:AVERAGE:0.5:1h:5y
RRA:MAX:0.5:1h:2y
```

```
step = 1
  ....
rra[0].rows = 604800
rra[1].rows = 89280
rra[2].rows = 105408
rra[3].rows = 26784
rra[4].rows = 43920
rra[5].rows = 17568
  ....
rra[0].pdp_per_row = 1
rra[1].pdp_per_row = 30
rra[2].pdp_per_row = 300
rra[3].pdp_per_row = 300
rra[4].pdp_per_row = 3600
rra[5].pdp_per_row = 3600
```

 
### SQL databases

rrd is the hot thing, SQL is the long time archive.  
backup as well, so it's on a different machine, with a huge TB mirrored hard drive, accessible for elaborated backup machinery.
Why I may be interested in some fly-speck when it comes to monitoring feeback control loops, for sure I don't need those in the long term records.  

The SQL database time resoultion is hardcoded by the `-r 300` clause in `sync-counter-rrd-to-SQL.pl`:  
`my $tpl_rrd2csv = "./rrd2csv.pl %s %s  -eN -s$start -r 300 -a -x\\; -M -t ";`
The reason is that I have different data sources, eg photovoltaic power logging, with that same resolution.
SQL field selection is provided in 

It were not a big deal to have that configurably as well.  
However, imho it does not make much sense to feed values into a SQL that do not match rrd rra rates, due to interpolation effects.

the fields exported are defined in `rrd_def.pm`
```
our %SQL_export = (
	elbasics => { CF => 'AVERAGE' , fields     => [ qw ( P1 P2 P3 ) ] } ,
	E_unidir => { CF => 'LAST'    , any   => 1 } ,
	E_bidir  => { CF => 'LAST'    , any   => 1 } ,
	totalP   => { CF => 'AVERAGE' , fields     => [ qw ( Ptot ) ] } ,

) ;
```
I only want total power and energy in my archive. 
No Voltages, no Currents, no apparent power, no THD....
There is still some redundancy, since energy is the the integral of Power.
However, there is the issue of differential vs integral errors. And when it boils down to money, energy drawn from grid and energy supplied to grid has different pricing (and more....), so I don't want to destroy information by adding those up.


### SQL upload `tmp/*.csv`

I still have `START=e-2d` in my `secret.pwd` and call this by `cron` every three hours.  
So there is an overlap by factor of 16.  
However, these 2 days fill just some 400 K - no issue.  
  
So even long term replays might not hit disk space limits. Well, be prudent. nevertheless...   


## timing issues

### SQL upload `tmp/*.csv`- again

The high overlap for sql upload causes 100 % CPU loads for some seconds.
So may be I might
* reduce the cron interval
* reduce even more the replay time, in result
* recue the overlap
* maybe have a redundant 'gap filler' long term overlap upload once a day or so.


### rrd updates
read and understand http://rrdtool.vandenbogaerdt.nl/process.php  
If you don't undestand it, read it again.  
I hat to read it three times, and a lot of futile tempering with my rrd inbetween.  
And for sure, still many improvements possible....


### cron job concurrency

Since I have a couple of similiar projects on my tiny box, I trie to stagger cron jobs.
I switched from a fixed apprach aka `2-23/3 * * * * ... my/cmd....` to some randomized staggering:

`30 */3    * * *  rnd_sleep.sh 1200 ;  cd ~wrosner/eastron_SDM/mySDMpoller/ ; ./sync-counter-rrd-to-SQL.pl > /dev/null  2>&1`

where `rnd_sleep.sh ` is just a little wrapper
```
....$ cat /usr/bin/rnd_sleep.sh
#!/bin/bash
sleep $(( RANDOM % $1 ))
```
Why? I had to learn that cron runs `/bin/sh`, not `/bin/bash` on debian-of-the-shelf.  
And many environment variables are missing as well....
