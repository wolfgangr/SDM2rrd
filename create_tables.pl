#!/usr/bin/perl
# crude hack to create tables
# print debug to SDTERR
# working output to file


use Data::Dumper;


# 
my %sql_tables;
my $sql_tables_dump = `./test-SQL-def.pl 2> /dev/null`;

# my %sql_tables = eval ($sql_tables_dump );

eval ($sql_tables_dump );

# my $sql_tables = eval "(foo => bar)" ;

print $@ ; # eval error message
print "hello? \n";
# print $sql_tables_dump;
print "hello again \n";
print Dumper ( \%sql_tables ) ;

eval ' @foo = qw ( pi pa po ) ';
print @foo ;
print Dumper ( \@foo ) ;
