#!/usr/bin/perl -w
use strict ;
#  https://metacpan.org/pod/release/LDS/CGI.pm-3.33/CGI.pm
  # CGI script that creates a fill-out form
  # and echoes back its values.

use CGI qw/:standard/;
use Data::Dumper; # () ;
# use Data::Dumper::Simple  ;

use RRDs ;
use utf8;
use Storable;

our $dtformat = '+\'%d.%m.%Y %T\'' ; # datetime format string for console `date`
our $RRDdtf = "+\'%d.%m.%Y %H:%M\'" ; # RRD does not like seconds here 
our $title = "Stromzähler @" . `hostname -f` ;
our $tmpdir= "./tmp" ; 

# load stored counterlist
# our $counterlist_f = './counterlist.dat';
# our @targets = qw ( INFINI-pwr INFINI-batt INFINI-volts );

# our %counterlist;
# my $clp = Storable::retrieve( $counterlist_f ); 
# %counterlist = %$clp;

# should'nt this better be in central counterlist?
# my @target_any = qw ( power energy basics quality ) ;
# our %target_h = (
# 	mains  => [ qw ( m_stacked m_lined flow energy )  ] ,
# 	mains_d =>  \@target_any ,
# ) ;

# all subs? counter get the default
# for my $cnt ( grep { /subs\d/ }  keys %counterlist ) {
# 	$target_h{ $cnt } = \@target_any ; 
# }

# DEBUG (\%target_h ); 

# my @sel_sorted = qw (   main details subs1 subs2 subs3 subs4 subs5 subs6 );
# my @sel_labels = [ 'Hauptanschluss  '  ] ;
# our @targets = @{$target_h{ main }} ;

our %counterlist;
our %target_h;

require './counter_graphs.pm';

my @counter_tags_sorted = sort keys %counterlist ;
# debug (sprintf ("param select: >%s<\n", param('select') ));
my $selected = (param('select') )  ||    (param('select_previous') )    ||  'mains' ;
# debug (sprintf ("\$selected: >%s<\n", $selected  ));

my @targets = @{$target_h{ $selected  }} ;

our $debug = param('debug') ? 1 : 0 ;  # we can feed this as GET variable aka ...url.pl?debug=1

debug (\%target_h, \@targets ) if $debug ;

my $navigator = "\n" ;
# $navigator .=  start_form  ;
for my $cnt (@counter_tags_sorted) {
	# active selection is marked bold
	my $nav_printf = ( $selected ne $cnt ) ? '%s' : '<b>%s</b>' ;

	$navigator .= sprintf '<button type="submit" name="select" value="%s">' , $cnt ;
	# $navigator .= '<b>' ;
	$navigator .=  sprintf $nav_printf ,  $counterlist{ $cnt }->{ Label } ;
	# $navigator .= '</b>' ;
	$navigator .= '</button>' ; 

	$navigator .= " \n" ;

}
# memorize some state - selection and debug
$navigator .= sprintf '<input type="hidden" name="select_previous" value="%s">', $selected ; 
$navigator .= sprintf '<input type="hidden" name="debug" value="%s">', $debug ;


# $navigator .=  end_form  . "\n" ;  



# debug (  \%target_h ,  \@targets, \%counterlist , $navigator ) ;

# DEBUG (  $target_h{ main } );
# DEBUG (  $target_h->{ main } );

# calculate interval:
# try to parse rrd AT notation
# - if 2 of (start / end / int ) are given, calcuate the third
# - if 3 are given, ignore int
# - if only start is given, assume end as now and calc int
# - if end is given, asume int as 1 day
# - if only int is given, assume end as now
# - if nothing is given, assume end as now and int as 1d


our ( $frm_start, $frm_end, $frm_intvl  ) ;


if (param('start') and param('end')) {
  $frm_start = param('start')  ;
  $frm_end   = param('end')  ;

} else  {
    $frm_intvl = param('intvl') || '1d';

  if (   param('start') and ! param('end')) {
    $frm_start = param('start')  ;
    $frm_end = sprintf "s+%s", $frm_intvl ;

  } else {  
    $frm_start = sprintf "e-%s", $frm_intvl ;
    $frm_end   = param('end')  || 'n' ;
  }
}

# still weird cases not catched:
# - circular reference 
# - in case of overdefined conflicting vars: 'intvl' is kept in form
# but processing 
if (0) { 
 debug ( sprintf ( "preprocessing \n"
                 . " frm_start %s   frm_end %s   frm_intvl %s  \n"
		 . " %s  %s  %s  \n" 
                 . " param('start')= >%s<   param('end') >%s<   param('intvl') >%s<  \n" ,
             	$frm_start, $frm_end, $frm_intvl,
	     	bool2str ($frm_start) , bool2str ($frm_end), bool2str ($frm_intvl),
	        param('start') , param('end') , param('intvl'),

         ) );
}


# my ($frm_start_clone, $frm_end_clone) = ($frm_start, $frm_end);
our ($numstart, $numend) = RRDs::times($frm_start, $frm_end);
my $rrds_err = RRDs::error;

if ($rrds_err) {  
  if ( $rrds_err =~ /start and end times cannot be specified relative to each other/ ) {
	  debug ("to do: resolve circular definition");
	  # $frm_start = 'e-1d';
    $frm_end = 'n';
    ($numstart, $numend) = RRDs::times($frm_start, $frm_end);
  } else {
    # report other parsing and conversion errors
    DEBUG ( sprintf '  RRD reportet error "%s" %s start->|%s|<   end->|%s|<  ', 
	    RRDs::error, "\n", $frm_start, $frm_end) ;
  }
} 

our $interval = $numend - $numstart;
$frm_intvl =  $frm_intvl || param('intvl') || $interval ; # keep frm or set to seconds if missing

unless ($interval) {
 
 # should not be here, if RRD is working as expected
 debug ( sprintf ( "after processing \n"
                 . " frm_start=>|%s|  frm_end=>|%s|<  frm_intvl=>|%s|< \n"
		 . " numstart=>|%s|  numend=>|%s|<  interval=>|%s|< \n" 
		 . " param('start')=>|%s|<  param('end')=>|%s|<  param('intvl')=>|%s|< \n" ,
	     $frm_start, $frm_end, $frm_intvl, 
	     $numstart, $numend , $interval,
	     param('start') , param('end') , param('intvl'),
	 ) );
}

#~~~~~~~~~~~~~~~~~

my $recalc =0;
if ( param('shift_ll')) {
   $frm_end =  rrddatetime($numend -= $interval);
   $frm_start = rrddatetime($numstart = $numend - $interval);
   $frm_intvl = $interval;
} elsif ( param('shift_l')) {
   $frm_end = rrddatetime($numend -= $interval / 2 );
   $frm_start = rrddatetime($numstart = $numend - $interval);
   $frm_intvl = $interval;
} elsif ( param('shift_rr')) {
   $frm_end = rrddatetime($numend += $interval);
   $frm_start = rrddatetime($numstart = $numend - $interval);
   $frm_intvl = $interval;
} elsif ( param('shift_r')) {
   $frm_end = rrddatetime($numend += $interval / 2 );
   $frm_start = rrddatetime($numstart = $numend - $interval);
   $frm_intvl = $interval;
} elsif ( param('zoom_out')) {
   $frm_end = rrddatetime($numend += $interval / 2 );
   $interval *= 2 ;
   $frm_start = rrddatetime($numstart = $numend - $interval);
   $frm_intvl = $interval;
} elsif ( param('zoom_in')) {
   $frm_end = rrddatetime($numend -= $interval / 4 );
   $interval /= 2 ;
   $frm_start = rrddatetime($numstart = $numend - $interval);
   $frm_intvl = $interval;

}

# rrd does not seem to like human readable second formats?
#if (0) {
#  $frm_start = mydatetime($numstart) ;
#  $frm_end   = mydatetime($numstart) ;
#  $frm_intvl = mytimediff2str ($interval);
#}
# ===================================== create chart(s) =====================================================

#  --start, --end, --height, --width, --base  werden dynamisch erstellt
#   --imgformat=PNG --interlaced
# der Rest wird in einem Deffile geladen
#
for my $target (@targets) {
  my $rrdg_img = sprintf "%s/%s.png", $tmpdir, $target ;
  my $rrdg_def = sprintf "./%s.rrd-graph",  $target ;
  # my $rrdg_tail = `cat $rrdg_def` ;

  my $rrdg_string = sprintf ("%s\n" , $rrdg_img)
    . sprintf ("--start\n%s\n" ,   $numstart )
    . sprintf ("--end\n%s\n" ,     $numend ) 
  ;

  $rrdg_string .=  sprintf ("--step\n%s\n" ,    scalar param('res') )    if (param('res' ));
  $rrdg_string .=  sprintf ("--width\n%s\n" ,   scalar param('width') )  if (param('width')) ;
  $rrdg_string .=  sprintf ("--height\n%s\n" ,  scalar param('height') ) if (param('height')) ;

   $rrdg_string .=  "--imgformat=PNG\n"
    . "--interlaced\n"
    # . $rrdg_tail
  ;

  my @rrdg_array = split '\n', $rrdg_string;

  my @tail = graph_spec ($selected, $target);
  push @rrdg_array ,  @tail ;

if ($debug) {
  debug ("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
  debug (\@rrdg_array, $selected, $target );
}

  # my ($result_arr,$xsize,$ysize)  = RRDs::graph($rrdg_string);
  my $res_hash = RRDs::graph( @rrdg_array  );
  $rrds_err = RRDs::error;
  if ($rrds_err) {
    my $rmmsg = `rm $rrdg_img `;
    debug ( sprintf "  RRD::graph error '%s'  \n",   RRDs::error, @rrdg_array, $rmmsg  ) ;
    
  }

  # DEBUG ($res_hash) ;
}
# ====================================== start HTML rendering ==================================================
STARTHTML:
print header,
        start_html($title),
        h3($title),
	# hr,


	"<table>" , start_form ,  
	"\n<tr><td colspan=999><hr></td></tr>\n", 
  ;

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  print "<tr><td colspan=999>";
  print $navigator;
  print "</td></tr>\n" ;
  print "<tr><td colspan=999><hr></td></tr>\n" ; 
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  
	# start_form,
print "\n<tr><td>" ,
        submit (-name=>'load', -value=>'Laden'),
       "</td>\n",
	;

printf '<td>ab:<input  type="text" name="start" value="%s" size="7" /></td>' , $frm_start ;
printf '<td>bis:<input type="text" name="end"   value="%s" size="7" /></td>' , $frm_end   ;
printf '<td>Int:<input type="text" name="intvl" value="%s" size="7" /></td>' , $frm_intvl  ;

print
	"\n<td>", "|</td><td>" , 
	   submit( -name=>'shift_ll', -value=>'<<', -size=>1   ),
        "</td>\n<td>",
           submit( -name=>'shift_l', -value=>'<', -size=>1   ),
        "</td>\n<td>",
           submit( -name=>'shift_r', -value=>'>', -size=>1   ),
        "</td>\n<td>",
           submit( -name=>'shift_rr', -value=>'>>', -size=>1   ),
        "</td>\n<td>", "|</td><td>" ,

           submit( -name=>'zoom_out', -value=>'-', -size=>1   ),
        "</td>\n<td>",
           submit( -name=>'zoom_in', -value=>'+', -size=>1   ),
        "</td>\n<td>",
	   defaults ( -value=>'>|<', -size=>1   ),
        "</td>\n<td>", "|</td>" ,

	"<td>Res:" ,
        popup_menu(-name=>'res',  -size=>1 , -default=>'300', 
                   -values=>['30','300','3600','86400']),

        "</td>\n<td>",
        "B:",textfield(-name=>'width' ,
                -default=>'600', -size=>1  ),
        "</td>\n<td>",
        "H:",textfield(-name=>'height' ,
                -default=>'140',  -size=>1   ),
	
	"</td></tr>" , end_form, #, "</table>\n",
	# end_form,
  ;
print "\n<tr><td colspan=999><hr></td></tr>\n";
print "<tr><td colspan=999><font size='-1'>\n";   
printf "start: <b>'%s'</b> -> %d = %s\n" , $frm_start , $numstart, mydatetime($numstart,) ;
print "  &nbsp;&nbsp;&nbsp;  \n";
printf "end: <b>'%s'</b> -> %d = %s\n" , $frm_end ,    $numend  , mydatetime($numend) ;
print "  &nbsp;&nbsp;&nbsp;  \n";
printf "interval: <b>'%s' </b> -> %d s = %s\n" , $frm_intvl , $interval, mytimediff2str($interval);
print "</font></td></tr>\n<tr>";
# "<td colspan=999><hr></td></tr>\n"; 
   ;


#--------------------------------------------------------------------------------------
# render the images
   # colspan=999 is a crude hack
print "\n<tr><td colspan=999><hr></td></tr>\n";

for my $target (@targets) {
  my $rrdg_img = sprintf "%s/%s.png", $tmpdir, $target ;

  print "<tr><td colspan=999>";
  printf '<img src="%s" >' , $rrdg_img ;
  print "</td></tr>\n";

}

print "</table>\n";
goto ENDHTML ;
# ~~~~~~~~~~ rrd time debug


STARTDEBUG:

print "\n<hr><pre><code>\n";

printf "rrd times start %s -> %d = %s<br>\n" , $frm_start , $numstart, mydatetime($numstart,) ;
printf "rrd times end   %s -> %d = %s<br>\n" , $frm_end ,    $numend  , mydatetime($numend) ;
printf "rrd times interval %s -> %d s = %s<br>\n" , $frm_intvl , $interval, mytimediff2str($interval);

print "\n</code></pre>\n";

# end %d interval: %d"

# ~~~~~~~~ simple variable dump

HASHDEBUG:
print "\n<hr><p>\n";
print CGI::Dump();

# ~~~~ full CGI object dump
print "\n<hr>\n<pre><code>\n";
my $query = new CGI;
print Dumper($query);
print "\n</code></pre><hr>\n";


ENDHTML:
print end_html, "\n";


exit;
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sub mydatetime {
  my $arg = shift;
  my $dtf = shift;
  $dtf = $dtformat unless $dtf ;
  my $rv =`date -d \@$arg $dtf` ;
  chomp $rv;
  return $rv ;
}

sub rrddatetime {
  my $arg = shift;
  return mydatetime ($arg , $RRDdtf) ;
}

# converts number of seconds to human readable format
sub mytimediff2str {
  my $seconds = shift;

  my ($d, $r ) = mymodulo ($seconds, 60);
  my $res = sprintf "%ds", $r;
  return $res unless $d;

  ($d, $r ) = mymodulo ($d, 60);
  $res = sprintf "%dm, %s", $r, $res;
  return $res unless $d;

  ($d, $r ) = mymodulo ($d, 24 );
  $res = sprintf "%dhr, %s", $r, $res;
  return $res unless $d;

  ($d, $r ) = mymodulo ($d, 7);
  $res = sprintf "%dd, %s", $r, $res;
  return $res unless $d;

  $res = sprintf "%dw, %s", $d, $res;
  return $res;
}

# moduolo div returning both mod an remainder
sub mymodulo {
  my ($a, $b) = @_;
  my $mod = $a % $b ;
  # $a -= ($b * $mod);
  return ( ($a - $mod) / $b, $mod  );
} 

# debug with continued laoding
sub debug {
  print
    "\n<pre><code>\n" .
    # Dumper ( @_), 
    (Data::Dumper::Dumper ( @_)) . 
    "\</code></pre>\n" 
  ;
}

# final die like debug
sub DEBUG {
    print header .
    start_html('### DEBUG ###') .
    debug ( @_) .
    end_html
  ;
  exit; # is it bad habit to exit from a sum??  
}

# return true or false label
sub bool2str {
  return shift ? 'TRUE' : 'FALSE' ;
}
