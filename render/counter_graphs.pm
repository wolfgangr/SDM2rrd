# implement the dynamic generation of graph specs for counters

use Cwd();

# all the heredocs 
our $rrd_tpl_mains_stacked;
our $rrd_tpl_mains_lined;
require './counter_graph_templates.pm';


$rrdpath = Cwd::realpath ( '../rrd');
$rrd_printf = $rrdpath .'/mySDM_%s_%s.rrd' ;

# load stored counterlist
our $counterlist_f = './counterlist.dat';
# our @targets = qw ( INFINI-pwr INFINI-batt INFINI-volts );

our %counterlist;
my $clp = Storable::retrieve( $counterlist_f );
%counterlist = %$clp;

my @subs_counters = grep { /subs\d/ } sort  keys %counterlist ;

# should'nt this better be in central counterlist?
my @target_any = qw ( power energy basics quality ) ;
our %target_h = (
        mains  => [ qw ( m_stacked m_lined flow energy )  ] ,
        mains_d =>  \@target_any ,
) ;

# all subs# counter get the default
# for my $cnt ( grep { /subs\d/ }  keys %counterlist ) {
for my $cnt ( @subs_counters ) {
        $target_h{ $cnt } = \@target_any ;
}


my %counter_default_colors = ( 
	mains => '0000FF' ,  
	mains_d => '0000aa',
	subs1 => 'FFA500', 
	subs2 => '008000', 
	subs3 => '800080', 
	subs4 => 'FFD700', 
	subs5 => 'FF0000', 
	subs6 => '00FF00', 
) ;



#~~~~~ end of setup stuff~~~~~~~~~~~~~~~~~~~

#=================== called by CGI ===============================
# replace the static rrd-graph files
# @tail_lines = graph_spec ($counter, $template) 
sub graph_spec {
	my ($counter, $template) = @_ ;
	my @rvs;

	if ($counter eq 'mains' and  $template eq 'm_stacked' ) {
		return main_area_spec(  @subs_counters ) ;
	}

        if ($counter eq 'mains' and  $template eq 'm_lined' ) {
                return main_line_spec(  @subs_counters ) ;
        }

	# @rvs = rrdg_lines_ary ($rrd_tpl_mains_stacked);
	# return @rvs;
	#
	# ... if (noting ( else )) { ....
	return dummy_spec() ;
}


sub main_line_spec {

        my @rvs;
        push @rvs, '--title=Verbrauch pro Zweig' ;
        # push @rvs, '--upper-limit=20000';
        push @rvs, '--lower-limit=-0.5';
        push @rvs, '--rigid';

	# Nullinie
	# push @rvs, 'LINE1:0#000000';

        # DEF
        for my $cnt ( 'mains_d', @_) {
                my $fn = sprintf $rrd_printf, $cnt, 'totalP';
                my $def = sprintf "DEF:def_%s=%s:Ptot:AVERAGE", $cnt ,$fn;
                push @rvs, $def;
        }

        # revert direction if required
        for my $cnt ('mains_d' , @_) {
                my $dir = $counterlist{ $cnt }->{ direction } ;
                my $rpn = '1000,/,' . $dir . ',*,' ;
                my $cdef = sprintf "CDEF:cdef_%s=def_%s,%s", $cnt, $cnt, $rpn  ;
                push @rvs, $cdef;
        }
        
        # thin lines 
        for my $cnt (@_) {
                my $area = sprintf "LINE1:cdef_%s#%s:%s", $cnt,
                        $counter_default_colors{ $cnt } ,
                        $counterlist{ $cnt }->{ Label } ;
                push @rvs, $area ;
        }

        # mains LINE
        for my $cnt ('mains_d') {
                my $line = sprintf "LINE3:cdef_%s#%s:%s", $cnt,
                        $counter_default_colors{ $cnt } , 'Gesamt' ;
                push @rvs, $line ;
        }

	push @rvs, 'LINE1:0#000000::dashes=1,4,5,4';

        return @rvs ;
}



# 
sub main_area_spec {
	
	# $rrd_printf 
	my @rvs;
	push @rvs, '--title=Verbrauch Summe' ;
	# push @rvs, '--upper-limit=20000';
	push @rvs, '--lower-limit=-0.5';
	push @rvs, '--rigid';

	# DEF
	for my $cnt ( 'mains_d', @_) {
		my $fn = sprintf $rrd_printf, $cnt, 'totalP';
		my $def = sprintf "DEF:def_%s=%s:Ptot:AVERAGE", $cnt ,$fn;
		push @rvs, $def;
	}

	# revert direction if required
	for my $cnt ('mains_d' , @_) {
		# my $dcef = sprintf "CDEF:cdef_%s=0,def_%s,-", $cnt, $cnt;
		# my $rpn = '';
		# if ( defined ( my $dir = $counterlist{ $cnt }->{ direction }) ) {
		my $dir = $counterlist{ $cnt }->{ direction } ;
		my $rpn = '1000,/,' . $dir . ',*,' ;
		# ',' . $dir . ',*' ;
		#}
		my $cdef = sprintf "CDEF:cdef_%s=def_%s,%s", $cnt, $cnt, $rpn  ;
		push @rvs, $cdef;
	}
	
	# stacked AREA s
	for my $cnt (@_) {
		my $area = sprintf "AREA:cdef_%s#%s:%s:STACK", $cnt,
			$counter_default_colors{ $cnt } ,
			$counterlist{ $cnt }->{ Label } ;
		push @rvs, $area ;
	}

	# mains LINE
	for my $cnt ('mains_d') {
		my $line = sprintf "LINE3:cdef_%s#%s:%s", $cnt,
			$counter_default_colors{ $cnt } , 'Gesamt' ;
		push @rvs, $line ;
	}

	push @rvs, 'LINE1:0#000000::dashes=1,4,5,4';
	return @rvs ;
}

#~~~~~~~~~~~~~~~~~~~~ helper subs ~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub dummy_spec {
	return rrdg_lines_ary ($rrd_tpl_mains_stacked);
}


sub dummy2_spec {
        return rrdg_lines_ary ($rrd_tpl_mains_lined);
}



# filter rrd graph lines
# perfrom bash style space and \ stripping
# @lines ( $textblock)
sub rrdg_lines_ary {
	my $input = shift;
	# my @result;

       return 
	       grep { $_ } map 
	       		{ /^\s*(\S.*[^\s\\])\s*\\?\s*$/ ; $1  } 
			split '\n',  $input ;


}

1;
