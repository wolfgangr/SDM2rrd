# how to use:

first, read disclamer!

```
cd setupFOOBAR
./my_configure.pl
sudo ./install.sh
```
either 
* be happy
* reinstall your system
* start debugging  
good luck!



## How it Works

demon management implements systemd service interface.

we have two distinct demons in this setup:
* `./USR-SDM-Poller.pl` , read over USR-TCP ....
* `./infini-SDM-MODBUS-sniffer.pl` --- SysV Message queue --->   `./mqsv-SDM2rrd.pl`  

We keep the service interface in distinct directories `setupUSR` and `setupInfiniSniff`.  
The associated service names are
* sdmUSRpoller.service
* sdmInfini.service

## common issues

(the figures are chosen at setup / early testing time and may vary due to tuning)

### `my_configure.pl`
... is expanding itself into `foobar.service`, `install.sh`, `cleanup.sh`.  
No special makefile magic, just plain heredocs and some variable substitution.  

### `cleanup.sh`
just removes the 3 files just expanded, leave anything else intact


### `install.sh`
To be called as root.  
Copies the unit file to `/where/ever/it/belongs`  
and performs the required `systemctl` acrobatic.  
Don't like it? Don't trust me? Different configurations?  
Do it manually!

### `foobar.service`
... is the **unit file** where `systemd magic` starts off.  
`man systemd.service` might be a good start to rtfM.  
`/etc/systemd/system/foobar.service` might be a good place for it on recent `systemd` debian.  
'works for me', at least.

Important deviations from minimalistic `systemd` howto-templates:  

#### `Type=notify` 
says that the `systemd` wait until **we report** succesful start.  
I let the watchdog do this, and only if it finds recent rrd updates.  
So, if anything goes wrong (software, LAN, gadget_under_test,  power ,....) we are not able to start the demon.  
I think this is OK in a stable environment.  

#### `NotifyAccess=all` 
is required to use cmd line `systemd-notify` notify tool.  
I did not find any PERL binding to libnotify. `system(systemd-notify)` does the job, but gets spawned as an owen process and thus reports to systemd with it's own PID.  
We go with that. No need for paranoia here.  

#### `User=`  
#### `WorkingDirectory=`  
... are real advantages compared to `cron`. Knowing who and where is coming makes live much easier.  
#### `ExecStart=` 
is the (full) path to our `start.sh`.  
#### `SyslogIdentifier=foobar-logger`
 since all `STDERR` goes to `/var/log/syslog`, we want to have tagged it with a mnemonic string for easy read and grep.
For the rest, see the watchdoc section.

### `start.sh`
The **executable** called by systemd.  
Just **spawns the watchdog and the logger**.  
From infamous cron environment acrobatics, only path config is left.  
And even this might go away, cutting executable lines from 5 to 2.  

#### `> /dev/null` 
It proved handy to keep the worker script easily debugabble outside of the systemd configuration.  
Just print serious debug to STDERR, and it will be logged in demon state as well.  
All verbose stuff goes to STDOUT.  
And if we really want debug in demon state, just remove the redirection to clobber /var/log/syslog.
  
I tried returnig to the caller by forking aka `log2rrdpl &` as well  , but this seems to be mutually exclusive with the `notify`.  


### `watchdog.pl`
I replaced the shell script `watchdog.sh` from the cron machine by a tiny little perl script.  
It's written as infinite - sleeping-most-of-the-time - called-once demon.  
So there is no iterative process creation overhead. It's hard to find in in `top` at all.  

Functionally it does the same thing, at much higher rate, and presumably much lower system load:  
Everey once a while aka `$looptime` seconds, it calls a `rrdupdate last` on all `@watched` databases in `$rrddir`.  
If the **last update is younger than `gracetime`**, anything is assumed to **work well**.  
This finding is reported to `systemd` by issueing **`systemd-notify 'WATCHDOG=1'`**.  

The first time such a succesful update is found, an extra **`"systemd-notify 'READY=1'`** is reported before.  
Due to the matching **`Type=notify`** clause in the unit file this is when `systemd` considers our **`foobar.service`** successfully **up and running**.  
When we call eg `sudo systemctl start foobar.service`, this call will block until systemd receives this `READY=1` -   
until `TimeoutStartSec=180` is over or the impatient user hits <^C>.  

If anything ist fine, this is just a matter of seconds.  
This is why I added some test polling rate `$loopt_onfail`  to speed up detection of succesful start.  

## watchdog timing
... may depend on the time pattern the foo-bar-gadeget-under-surveillance ist queried.  

Provided succesful logging, the watchdog reports 'no need to worry' aka `WATCHDOG=1` every `$looptime = 20`seconds. 

Once updates grow overdue, it takes a maximum of `$looptime = 20` for the watchdog to find out and stop reporting `WATCHDOG=1` to systemd.  
There we have `WatchdogSec=60` systemd will wait before it tries to reastart everything.  
So this adds up to `gracetime`.  
  
Once restart is triggered, `SIGTERM` is sent to all process in `KillMode=control-group`, i.e. the logger, the watchdog and maybe some subshelled cmd line spawns. If there are still undeads after `TimeoutStopSec=30`, they are hit by `SIGQUIT`.  
  
After another `RestartSec=20` systemd tries to start afreash again.  


## specific issues

### `setupUSR`  
implementing `sdmUSRpoller.service`  
for demon  `./USR-SDM-Poller.pl` and its associated babysitter `../watchdogUSR_systemd.pl`

The list of counters to be polled is assembled at watchdog start (i.e. at demon start) from the currently valid configuration.  
So I hope proper changes in config will keep stuff in sync.   
... well, as long as there is only 
* one MODBUS for them
* one USR-TCP-device
* one `$bustag = 'tcp-241'`  

If I ever add a second bus, I might simply duplicate stuff with a different bustag.  
May be even for the third bus.  
But if I ever happen to configure dozens of them, I think it is time to fork the code and add another layer of config expansion.  
If you happen to do so for your multinational company, don't forget to pay me my due beer once we met :-)

### `setupInfiniSniff`

#### two logic busses
... a challenge that hits me earlier as expected:  
The infini bus is configured as two distinct busses:
* `MODBUS-infini` referring to pure passive sniffing
* `MODBUS-hack` referring to readouts acquired by injecting own commands into the idle periods  
  
Reason: This is not yet testet under harsh production condititions, so we may need to revert.  
  
In consequnce we have to combine two (skd of logical) bus tags for one physical bus:  
`my @bustags = qw ( MODBUS-infini MODBUS-hack  );`  

#### two processes
We have a sender and a reader on the message queue, so we have to start them both.  
We did this already in the `cron` environment, so nothing new, still massive simplifaication.  
We kept the setting with distinct logs for couter bus errors and system errors.  

#### ...plus a babysitter

... so this is what it looks like when correctly brought up:
```
   CGroup: /system.slice/sdmInfini.service
           ├─31624 /bin/bash /home/whoever/eastron_SDM/mySDMpoller/setupInfiniSniff/start.sh
           ├─31626 /usr/bin/perl ./watchdogInfini_systemd.pl
           ├─31627 /usr/bin/perl ./mqsv-SDM2rrd.pl
           └─31659 /usr/bin/perl ./infini-SDM-MODBUS-sniffer.pl
```

#### cleaning up the message queue
... is performed by calling a slightly modified version of `mqsv-cleanup-systemd.pl`  
by a `ExecStopPost=$setup_dir/mqsv-cleanup-systemd.pl` stanza.  

Since probably systemd already killed the users of the queue, we reduced the sleep times.  
May be it were even possible to leave the queue untouched, but , well, hm, ....



