# implement the dynamic generation of graph specs for counters

use Cwd();

# all the heredocs 
# our $rrd_tpl_mains_stacked;
# our $rrd_tpl_mains_lined;
# require './counter_graph_templates.pm';


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
my @target_any = qw ( power  basics energy quality ) ;
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
	L1 => 'FF0000' ,
	L2 => '0000ff' ,
	L3 => '00bb00' ,
        total => '000000',	
) ;



#~~~~~ end of setup stuff~~~~~~~~~~~~~~~~~~~

#=================== called by CGI ===============================
# replace the static rrd-graph files
# @tail_lines = graph_spec ($counter, $template) 
sub graph_spec {
	my ($counter, $template) = @_ ;
	my @rvs;

	if ($counter eq 'mains' and  $template eq 'm_stacked' )    { return main_area_spec(  @subs_counters ) ; }
        if ($counter eq 'mains' and  $template eq 'm_lined' ) 	   { return main_line_spec(  @subs_counters ) ; }
	if ( $template eq 'power') 	{ return subs_power_spec ($counter) ; }	
	if ( $template eq 'basics')      { return subs_basics_spec ($counter) ; }	 
	if ( $template eq 'energy')      { return subs_energy_spec ($counter) ; }
	if ( $template eq 'quality')      { return subs_quality_spec ($counter) ; }

	# @rvs = rrdg_lines_ary ($rrd_tpl_mains_stacked);
	# return @rvs;
	#
	# ... if (noting ( else )) { ....
	return dummy_spec() ;
}

#----------------------------------------
sub subs_quality_spec {
        my $counter = shift;

        my @rvs;
        push @rvs, '--title=Störungsanalyse - ' .  $counterlist{ $counter }->{ Label }  ;
        push @rvs, '--upper-limit=120';
        push @rvs, '--lower-limit=-120';
        push @rvs, '--rigid';
        push @rvs, '--vertical-label=Prozent';
        push @rvs, 'TEXTALIGN:left';

	# DS
	for my $P ( qw ( 1 2 3 tot ) ) {
	   for my $prm ( qw ( VAr thdI thdU )) {
		my $fn = sprintf $rrd_printf, $counter, 'elquality';
		my $tag = $prm . $P ;
                my $def = sprintf "DEF:def_%s=%s:%s:AVERAGE", $tag, $fn , $tag    ; # $P  ,$fn , $P;
                push @rvs, $def;
	   }
	}

	# retrieve power to calculate cos phi aka power factor
	for my $P ( qw ( 1 2 3 ) ) {
		my $fn = sprintf $rrd_printf, $counter, 'elbasics' ;
		my $def = sprintf "DEF:def_P%s=%s:P%s:AVERAGE", $P, $fn , $P    ;
		push @rvs, $def;
	}

	# cdef for cos phi
	push @rvs, 'CDEF:def_Ptot=def_P1,def_P2,def_P3,+,+';
	for my $P ( qw ( 1 2 3 tot ) ) {
		#
		##  
		my $rpn = sprintf ('def_VAr%s,DUP,DUP,*,def_P%s,DUP,*,+,SQRT,/,100,*', $P , $P )  ;
		my $cdef = sprintf "CDEF:def_cosphi%s=%s", $P ,$rpn   ;
		push @rvs, $cdef;
	}

	# 
	
        for my $P ( qw ( 1 2 3 tot ) ) {
            for my $prm ( qw ( thdI thdU cosphi )) {
		my $clr_idx = ($P eq 'tot') ? 'total' : 'L'.$P ; # color index

		# my $dashing =  ($prm eq 'thdI' ) ? '3,2' :  '1,4'  ; 
		my $dashing = '';   ':dashes'  ;
		$dashing .= ':dashes=3,2' if ($prm eq 'thdI' );
		$dashing .= ':dashes=1,4' if ($prm eq 'thdU' );

		my $label = sprintf "%s(%s)", $prm, $P;
		my $indextag = $prm.$P ;

                my $ln = sprintf "LINE1:def_%s#%s:%s%s",  $indextag  , 
                        $counter_default_colors{ $clr_idx  },  
			$label, $dashing ;
			# $counterlist{ $cnt }->{ Label } ;
                push @rvs, $ln ;
	    }
	}



	# zero line
	push @rvs, 'LINE1:0#000000::dashes=1,4,5,4';
	push @rvs, 'LINE1:100#000000::dashes=1,4,5,4';
	push @rvs, 'LINE1:-100#000000::dashes=1,4,5,4';
        return @rvs ;


}


#-------------------------------------
sub subs_basics_spec {
 	my $counter = shift;

        my @rvs;
        push @rvs, '--title=Stromaufteilung - ' .  $counterlist{ $counter }->{ Label }  ;
        # push @rvs, '--upper-limit=20000';
	# push @rvs, '--lower-limit=-0.5';
	# push @rvs, '--rigid';
	push @rvs, '--vertical-label=Ampere';
	push @rvs, 'TEXTALIGN:left';

	# DS
	for my $P ( qw ( 1 2 3 ) ) {
		my $fn = sprintf $rrd_printf, $counter, 'elbasics';
                my $def = sprintf "DEF:def_I%d=%s:I%d:AVERAGE", $P  ,$fn , $P;
                push @rvs, $def;
	}

	# no need to care for direction for bare AC current
	# but we may like some average line
	push @rvs, 'CDEF:cdef_Iavg=def_I1,def_I2,def_I3,3,AVG';


        for my $P ( qw ( 1 2 3 )  ) {
		# my $Plabel = 'P' . $P ;
                my $ln = sprintf "LINE1:def_I%s#%s:%s",  $P ,
                        $counter_default_colors{  "L$P"}, "I(L$P)"  ;
			# $counterlist{ $cnt }->{ Label } ;
                push @rvs, $ln ;
        }

        for my $P ( qw ( avg )  ) {
                # my $Plabel = 'P' . $P ;
                my $ln = sprintf "LINE2:cdef_I%s#%s:%s",  $P ,
                        $counter_default_colors{ 'total' }, "I avg"  ;
                        # $counterlist{ $cnt }->{ Label } ;
                push @rvs, $ln ;
        }


	# zero line 
	push @rvs, 'LINE1:0#000000::dashes=1,4,5,4';
        return @rvs ;
}

#-------------------------------------

sub subs_energy_spec {
        my $counter = shift;

        my @rvs;
        push @rvs, '--title=Zählerstand - ' .  $counterlist{ $counter }->{ Label }  ;
        # push @rvs, '--upper-limit=20000';
        # push @rvs, '--lower-limit=-0.5';
        # push @rvs, '--rigid';
        push @rvs, '--vertical-label=kWh';
        push @rvs, 'TEXTALIGN:left';

	# DEF
	for my $P ( qw ( 1 2 3 tot ) ) {
                my $fn = sprintf $rrd_printf, $counter, 'E_unidir'; ### TODO for bidirs!
                my $def = sprintf "DEF:def_E%s=%s:E%s_sld:AVERAGE", $P ,$fn, 
			( $P ne 'tot' ) ? $P : '';
                push @rvs, $def;
        }

	# shift to zero start
	for my $P ( qw( 1 2 3 tot)  ) {
		# my $dir = $counterlist{ $counter }->{ direction } ;
		# my $rpn = '1000,/,' . $dir . ',*,' ;
		# my $rpnv =   ',FIRST'  ;
                my $vdef = sprintf "VDEF:E%s_offs=def_E%s,FIRST", $P, $P  ;
		# my $rpnc =   ',-'  ;
		my $cdef = sprintf "CDEF:E%s_plot=def_E%s,E%s_offs,-", $P, $P, $P  ;
                push @rvs, $vdef, $cdef;
        }

        # zero line
        push @rvs, 'LINE1:0#000000::dashes=1,4,5,4';
        return @rvs ;

}

#-------------------------------------

sub subs_power_spec {
 	my $counter = shift;

        my @rvs;
        push @rvs, '--title=Verbrauch - ' .  $counterlist{ $counter }->{ Label }  ;
        # push @rvs, '--upper-limit=20000';
	# push @rvs, '--lower-limit=-0.5';
	# push @rvs, '--rigid';
	push @rvs, '--vertical-label=Watt';
	push @rvs, 'TEXTALIGN:left';

	# DS
	for my $P ( qw ( tot ) ) {
		my $fn = sprintf $rrd_printf, $counter, 'totalP';
                my $def = sprintf "DEF:def_Ptot=%s:Ptot:AVERAGE",  ,$fn;
                push @rvs, $def;
	}
        for my $P ( qw ( 1 2 3 ) ) {
                my $fn = sprintf $rrd_printf, $counter, 'elbasics';
                my $def = sprintf "DEF:def_P%s=%s:P%s:AVERAGE", $P ,$fn, $P;
                push @rvs, $def;
        }


        # revert direction if required
        for my $P ( qw( 1 2 3 tot)  ) {
                my $dir = $counterlist{ $counter }->{ direction } ;
		# my $rpn = '1000,/,' . $dir . ',*,' ;
		my $rpn =  $dir . ',*,' ;
                my $cdef = sprintf "CDEF:cdef_P%s=def_P%s,%s", $P, $P, $rpn  ;
                push @rvs, $cdef;
        }

	# Area per Phase
        for my $P ( qw ( 1 2 3 )  ) {
		# my $Plabel = 'P' . $P ;
                my $area = sprintf "AREA:cdef_P%s#%s:%s:STACK",  $P ,
                        $counter_default_colors{  "L$P"}, "P(L$P)"  ;
			# $counterlist{ $cnt }->{ Label } ;
                push @rvs, $area ;
        }

	# line for phase total
        for my $P ( qw ( tot )  ) {
                # my $Plabel = 'P' . $P ;
                my $area = sprintf "LINE2:cdef_P%s#%s:%s",  $P ,
                        $counter_default_colors{ 'total'  }, "P gesamt"  ;
                        # $counterlist{ $cnt }->{ Label } ;
                push @rvs, $area ;
        }


	push @rvs, 'LINE1:0#000000::dashes=1,4,5,4';
	return @rvs;
}

sub main_line_spec {

        my @rvs;
        push @rvs, '--title=Verbrauch pro Zweig' ;
        # push @rvs, '--upper-limit=20000';
        push @rvs, '--lower-limit=-0.5';
        push @rvs, '--rigid';
	push @rvs, '--vertical-label=kW';

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
	push @rvs, '--vertical-label=kW';

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
	# return rrdg_lines_ary ($rrd_tpl_mains_stacked);
        my @rvs;
        push @rvs, '--title=Dummy 1' ;
	push @rvs, '--vertical-label=foo bar';
	push @rvs, 'LINE1:0#000000::dashes=1,4,5,4';
	push @rvs, 'LINE3:1#FF0000::dashes=3,3';

        return @rvs ;
}


sub dummy2_spec {
	# return rrdg_lines_ary ($rrd_tpl_mains_lined);
        my @rvs;
        push @rvs, '--title=Dummy 2' ;
	push @rvs, '--vertical-label=tralala';
        push @rvs, 'LINE1:0#000000::dashes=1,4,5,4';
        push @rvs, 'LINE3:-1#00ff00::dashes=3,5';

        return @rvs ;

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
