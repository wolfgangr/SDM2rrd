# how to use:

first, read disclamer!

```
./my_configure.pl
sudo ./install.sh
```
either 
* be happy
* reinstall your system
* start debugging
good luck!



# `systemd` setup machine

This is my first `systemd` start-stop configuration.  
So I keep my memories here - for me and may be interested public.  

## Old Times vs New Times

On development, I drafted the `watchdog.sh` with 'good old' unix style in mind.  
So my plan was to wirte sysV init scripts in the end.  
  
However, I had to find that the times of sysV init are gone without doubt, even if 10 yr old pro/con discussions still lingering on the web may tell sth else.  
`sytemd` is `PID0` in these days.

So I had to climb the `systemd` learning curve and found it not too steep at all.  
To be honest, I start to like it :-)  
When I compare my watchdog and my startup scripts, they cut down by 3/4.  
And the logger itself gets close to immortality - pure magic as it seems.  
  
I have some more project to `systemd`'emonize.  
This one is my trainig. So doc is a bit more exhaustive.  

When the stuff in this dir is working in the end, the "old" `cron` based `watchdog.sh` might well go away.  


## How it Works


### `my_configure.pl`
... is expanding itself into `guntamatic.service`, `install.sh`, `cleanup.sh`.  
No special makefile magic, just plain heredocs and some variable substitution.  

### `cleanup.sh`
just removes the 3 files just expanded, leave anything else intact


### `install.sh`
To be called as root.  
Copies the unit file to `/where/ever/it/belongs`  
and performs the required `systemctl` acrobatic.  
Don't like it? Don't trust me? Different configurations?  
Do it manually!

### `guntamatic.service`
... is the **unit file** where `systemd magic` starts off.  
`man systemd.service` might be a good start to rtfM.  
`/etc/systemd/system/guntamatic.service` might be a good place for it on recent `systemd` debian.  
'works for me', at least.

Important deviations from minimalistic `systemd` howto-templates:  

#### `Type=notify` 
says that the `systemd` wait until **we report** succesful start.  
I let the watchdog do this, and only if it finds recent rrd updates.  
So, if anything goes wrong (software, LAN, cauldron, power ,....) we are not able to start the demon.  
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
#### `SyslogIdentifier=guntamatic-logger`
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
Due to the matching **`Type=notify`** clause in the unit file this is when `systemd` considers our **`guntamatic.service`** successfully **up and running**.  
When we call eg `sudo systemctl start guntamatic.service`, this call will block until systemd receives this `READY=1` -   
until `TimeoutStartSec=180` is over or the impatient user hits <^C>.  

If anything ist fine, this is just a matter of seconds.  
This is why I added some test polling rate `$loopt_onfail`  to speed up detection of succesful start.  

## watchdog timing
We query our caouldron twice a minute add odd times, but log it with time rounded down to whole minutes.  
So, every minute, at sec 23 (in my test setting), we get new values, which, however, are already valued as 23 s old.  
The next value is not earlier than at second 83. Thus, `$gracetime = 120` allow for just one missing read.  
In a crowded, instable environment, this may be too short and trigger unnecessary restarts.  
Be prudent and watch log files.  

Provided succesful logging, the watchdog reports 'no need to worry' aka `WATCHDOG=1` every `$looptime = 20`seconds. 

Once updates grow overdue, it takes a maximum of `$looptime = 20` for the watchdog to find out and stop reporting `WATCHDOG=1` to systemd.  
There we have `WatchdogSec=60` systemd will wait before it tries to reastart everything.  
So this adds up to `gracetime`.  
  
Once restart is triggered, `SIGTERM` is sent to all process in `KillMode=control-group`, i.e. the logger, the watchdog and maybe some subshelled cmd line spawns. If there are still undeads after `TimeoutStopSec=30`, they are hit by `SIGQUIT`.  
  
After another `RestartSec=20` systemd tries to start afreash again.  
Nothing special, but simple and tested.  
Oh had I only tried this before writing my `watchdog.sh`....

There may be some default limit and retry slow down values.  
I did not want to screw my system to produce test cases.  
But may be, when the cauldron or the LAN returns back to service after some extended downtime, it may take some time or even manual action to bring loggin up again.
Just to keep in mind....

  







