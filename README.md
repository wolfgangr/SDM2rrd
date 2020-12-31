# SDM2rrd
## retrieve counter data from Eastron SDM630 energy counters an store them into a rrd round robin database
### Disclaimer
Don't expect this premature snippets to do anything of sense for you.  
Maybe, electricity counters are not designed to blow your basement or put your house onto fire.  
Well, mhh, who really knows?

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


