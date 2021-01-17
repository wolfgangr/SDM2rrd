


# how it works 
... and why did it become that complicated?  
Well, at the moment I have close to 30 rrds from my 7 counters and maybe some hundreds of registers.  
as many sql tables, rrd graph templates ....  
No chance to manually keep that in sync ....  
There is loads of default expansion implmented. Approach: Fill some PERL hash with individual values, and let a default filler running over it at the end. This is preferrably distinguished in the config-whatever.pm files, not hidden in the worker scripts.   

## handling counter register structure

SDM 630 is a beast that knows much more than just kWh. There are close to 200 registers.  
RTFM ... SDM-Manual ... cut'n-paste .... libreoffice calc .... what do I want? ->  `SDM630proto-usage.csv`  
Any register I want to retrieve gets a mnemonic `tag` associated with it.  
Only up to 40 registers are allowed for a single query. So I need to collect them to multiple query bursts.  
 `./test-extract-SDM-def.pl` is a debugging helper for this step.
 
 `my_counters.pm` keeps configuration for each of my physical RDM. There is some default procedure implemented.  
 in `rrd_def.pm` we decide how to aggregate the SDM register sets to rrd files and database tables.
 `extract-SDM-def.pm` merges registers and physical config into PERL hashes for other scripts.  
**`test-counter-def.pl` can test and debug** print this process. We get sth like:

`@SDM_regs` - imported definition of a single counter register  
| sequence | label | unit | query burst selector | mnemo tag |
```
@SDM_regs = ( [
    [ '1', '"Phase 1 line to neutral volts"',  '"V"', '1', '"U1"'
    ],
```

`%SDM_reg_by_tag` - hashed version to make code more readable, since we may access fields my hash key instead of array index.
```
%SDM_reg_by_tag = (
                    'U1' => {
                              'selector' => '1',
                              'desc' => 'Phase 1 line to neutral volts',
                              'par_no' => 1,
                              'unit' => 'V'
                            },
```

`%SDM_selectors` - group registers by coherent query bursts  
```
%SDM_selectors = (
                   '3' => {
                            '174' => 'E1_imp',
                            '175' => 'E2_imp',
                            '172' => 'E_sld',
                            '178' => 'E2_exp',
```

`%RRD_definitions` - are configured and expanded in `rrd_def.pm`  
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

**`%Counterlist`: configurations of physical counters**  
this is skd of a pivot point.  
`selectors` tell what query burst to read when polling SDM  
`rrds` tell us what to write, to expanded by `%RRD_definitions`  
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


## SQL database structure

~~There is no location to configure SQL tables. Instead, it is derived from the config machine outlayed above.  ~~

SQL table definition is included in `rrd_def.pm` as a reference to `rrd` definition.  
This way we can restrict SQL export to a limited subset of fields and rrd CF.  


```
our %SQL_export = (
	elbasics => { CF => 'AVERAGE' , fields     => [ qw ( P1 P2 P3 ) ] } ,
	E_unidir => { CF => 'LAST'    , any   => 1 } ,
	E_bidir  => { CF => 'LAST'    , any   => 1 } ,
	totalP   => { CF => 'AVERAGE' , fields     => [ qw ( Ptot ) ] } ,

) ;
```

`./test-SQL-def.pl` is just a modfied version of  `./test-counter-def.pl` as a development aid to print the expansion of this.  

```
./rrd/mySDM_mains_d_E_bidir.rrd => ./rrd/mySDM_mains_d_E_bidir.sql 
  has cols: E1_sld, E2_sld, E3_sld, E_sld, E1_imp, E2_imp, E3_imp, E_imp, E1_exp, E2_exp, E3_exp, E_exp
./rrd/mySDM_mains_d_elbasics.rrd => ./rrd/mySDM_mains_d_elbasics.sql 
  has cols: P1, P2, P3
./rrd/mySDM_mains_d_totalP.rrd => ./rrd/mySDM_mains_d_totalP.sql 
  has cols: Ptot
    .....
```


## data storage initialisation


```
create_SDM_rrd.pl 
create_tables.pl
create_tables.sh
```

do what their name implies and set up the data files according to the configured structure.  
rtfS aka rtf**Source**
I prefer to remove their executable flag to avoid accicential deletion of populated rrds and databases.

## database credentials

live in in `.gitignore`-ed `secret.pwd` and sourced by `create_tables.sh` and `sync-counter-rrd-to-SQL.pl`.  
```
PASSWD="tIhsVeRySECret12345"
USER=SDM_at_my_database
DB=SDM-counter
# START=e-2h
START=e-2d
# START=e-10d
HOST=database.server.IP.or.host.name.of.my.local.domain
TMPDIR=./tmp
```
START is provided in rrd time notation.  
A long time range helps to fill a new database with historic stuff (eg 10 days back, can as well be 100 or 1000d).  
For continued sync, this value should overlap with cron call intervals. may balance redundancy with system load here. 


