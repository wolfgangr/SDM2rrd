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


#### counter configuration

* `create_whatever_*.sh|pl` setup the data files
* SDM-Manual ... cut'n-paste .... libreoffice calc .... ->  `SDM630proto-usage.csv` 
  `extract-SDM-def.pm` 
* next item



