# SDM2rrd
## Yet another SDM electricity meter poller
### Why?
* have 7 of them (at the moment)
* wanna see more details (per phase, thd, ...) to identify causes of undue consumption
* need to integrate **Modbus MultiMaster** counter for my **voltronic infini 10k grid compensation** setup
* want it in a configurable way
* want to integrate it with other rrd
So I have to find my way between narrow banded rrd frontned and full fledged freedom of turing capable language.
I decided for last and 


### Data flow overview: SDM -> rrd -> SQL and HTML
* `create_whatever_*.sh|pl` setup the data files
* extended protocol definition goes to `*.pm` config files and other
* `USR-SDM-Poller.pl` polls 6 counters on a single MODBUS via USR-TCP232-304 and writes it to a bunch of `rrd` files
* `infini-SDM-MODBUS-sniffer.pl` sniffs the traffic between infini and its counter and adds additional querys in between
* `sync-counter-rrd-to-SQL.pl` uploads a selectable subset of a database
* web visualisation - still TODO - at the moment I hack with drraw
* watchdog, cron, and maintenance skripts to glue the stuff together



### Inspirations
https://github.com/riogrande75/sdm630poller  
From the hero of taming inifini inverters.  
however, does not fit into my data flow scheme (aggregate and visualize by rrd, long term capture and flexible evaluation by SQL)  
So, instead of adopting rio's PHP, I decided to restart from scratch with my preferred environment - PERL.  
(If you're inclined to call me an IT dinosaur - well, then I have nothing to counter...)  
  
https://github.com/bernisys/sdm630  
This is actually promisng to do the job wiht perl.  
But I could not get it working.  
I'm quite sure that the cheapy USR-TCP232-304 gadget I am using does not really do Modbus TCP, but plain good old Modbus RTU wrapped into TCP or UDP, whatever you prefer. Just have a look at the checksums...   
So I suspect that bernisys's sdm630 may expect true Modbus TCP as provided by really valuable gadgets? Who knows...  
And it asked for perl packages I could not find on debian.  
I've been used to work with CPAN. Great stuff. Nevertheless, I would be happy to avoid it in an IoT environment.  
Anyway, I decided that it might be easier to start the K.I.S.S. way from start.  
That's what I am trying to do here.  

### Disclaimer
Don't expect this premature snippets to do anything of sense for you.  
Maybe, electricity counters are not designed to blow your basement or put your house onto fire.  
Well, mhh, who really knows?




### how it works 
... and why did it become that complicated?  
Well, at the moment I have close to 30 rrds from my 7 counters and maybe some hundreds of registers.  
as many sql tables, rrd graph templates ....  
No chance to sync that manually....  

#### counter register structure

SDM 630 is a beast that knows much more than just kWh. There are close to 200 registers.  
RTFM ... SDM-Manual ... cut'n-paste .... libreoffice calc .... what do I want? ->  `SDM630proto-usage.csv`  
Any register I want to retrieve gets a mnemonic `tag` associated with it.  
Only up to 40 registers are allowed for a single query. So I need to collect them to multiple query bursts.  
 `./test-extract-SDM-def.pl` is a debugging helper for this step.
 
 `my_counters.pm` keeps configuration for each of my physical RDM. There is some default procedure implemented.  
`extract-SDM-def.pm` merges registers and physical config into PERL hashes for other scripts.  
`test-counter-def.pl` can test and debug print this process. We get sth like:

`@SDM_regs` imported definition of a single counter register
| sequence | label | unit | query burst selector | mnemo tag |
```
@SDM_regs = ( [
    [ '1', '"Phase 1 line to neutral volts"',  '"V"', '1', '"U1"'
    ],
```

`%SDM_reg_by_tag` hashed version to make code more readable
```
%SDM_reg_by_tag = (
                    'U1' => {
                              'selector' => '1',
                              'desc' => 'Phase 1 line to neutral volts',
                              'par_no' => 1,
                              'unit' => 'V'
                            },
```

`%SDM_selectors` group registers by coherent query bursts  
```
%SDM_selectors = (
                   '3' => {
                            '174' => 'E1_imp',
                            '175' => 'E2_imp',
                            '172' => 'E_sld',
                            '178' => 'E2_exp',
```

`%RRD_definitions` are configured and expanded in `rrd_def.pm`  
```
%RRD_definitions = (
                     'elquality' => {
                                      'rradef' => 'RRA:AVERAGE:0.5:30s:10d
RRA:AVERAGE:0.5:5m:1M
RRA:AVERAGE:0.5:1h:6M
RRA:MAX:0.5:1h:6M
',
                                      'heartbeat' => 30,
                                      'step' => 30,
                                      'fields' => [
                                                    'F',
                                                    'VAr1',
                                                    'VAr2',
                                                    'VAr3',
                                                    'VArtot',
                                                    'thdI1',
                                                    'thdI2',
                                                    'thdI3',
                                                    'thdItot',
                                                    'thdU1',
                                                    'thdU2',
                                                    'thdU3',
                                                    'thdUtot'
                                                  ]
                                    },
```

`%Counterlist`: configurations of physical counters  
`selectors` tell what query burst to read when polling SDM
`rrds` tell us what to write #### how is this mapped to tags????????????
```
%Counterlist = (
                 'subs2' => {
                              'rrds' => [
                                          'totalP',
                                          'E_unidir',
                                          'elbasics',
                                          'elquality'
                                        ],
                              'direction' => 1,
                              'ID' => 2,
                              'bus' => 'tcp-241',
                              'selectors' => \@all_selectors,
                              'Label' => 'Stall + Werkstatt'
```

... which in short is aggregated to our rrd and SQL-table structures:
```
 ===== rrd defs : elquality elbasics totalP totalP_hires E_unidir E_bidir =====
elquality
F VAr1 VAr2 VAr3 VArtot thdI1 thdI2 thdI3 thdItot thdU1 thdU2 thdU3 thdUtot
elbasics
P1 P2 P3 I1 I2 I3 U1 U2 U3
totalP
Ptot
totalP_hires
Ptot
E_unidir
E1_sld E2_sld E3_sld E_sld
E_bidir
E1_sld E2_sld E3_sld E_sld E1_imp E2_imp E3_imp E_imp E1_exp E2_exp E3_exp E_exp
```

  
#### data storage initialisation

`create_whatever_*.sh|pl` setup the data files according to the configured structure


