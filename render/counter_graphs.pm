# implement the dynamic generation of graph specs for counters

use Cwd();

# all the heredocs 
our $rrd_tpl_mains_stacked;
our $rrd_tpl_mains_lined;
require './counter_graph_templates.pm';


$rrdpath = Cwd::realpath ( '../rrd');


# load stored counterlist
our $counterlist_f = './counterlist.dat';
# our @targets = qw ( INFINI-pwr INFINI-batt INFINI-volts );

our %counterlist;
my $clp = Storable::retrieve( $counterlist_f );
%counterlist = %$clp;


# should'nt this better be in central counterlist?
my @target_any = qw ( power energy basics quality ) ;
our %target_h = (
        mains  => [ qw ( m_stacked m_lined flow energy )  ] ,
        mains_d =>  \@target_any ,
) ;

# all subs# counter get the default
for my $cnt ( grep { /subs\d/ }  keys %counterlist ) {
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
		return dummy2_spec() ;
	}
	# @rvs = rrdg_lines_ary ($rrd_tpl_mains_stacked);
	# return @rvs;
	#
	# ... if (noting ( else )) { ....
	return dummy_spec() ;
}


# 
sub main_area_spec {
	my $counterlist = shift;

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
