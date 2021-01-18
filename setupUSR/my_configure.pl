#!/usr/bin/perl

# this is a crude hack and not a make style configure script!


# find our working and root dir
# customize some helper scripts
# print some basic usage instructions


use warnings;
use strict;

use Cwd qw();


my $servicename = "guntamatic";
my $unit_dir = "/etc/systemd/system";  # this is OK for debian, on other systems this may vary

my $unit_file = "$servicename.service";

# my @helpers = qw(rrd2csv.pl rrdtest.pl rnd_sleep.sh);
# my $helper_dir = "/usr/local/bin"; 

my $setup_dir= Cwd::getcwd;
my $base_dir= Cwd::abs_path( $setup_dir . '/..');  


# my $username = `echo \$USER` ;
my @passdw = getpwuid($<);
my $username = $passdw[0];


print "username:  $username  \n";
print "unit_file: $unit_file \n";
print "setup_dir: $setup_dir \n"; 
print "base_dir:  $base_dir \n" ;

# die "DEBUG";

#  setup executable
#
my $installer_template = <<"EOF_INSTALLER";
# chmod 0644 $unit_file
cp -i ./$unit_file $unit_dir/$unit_file

systemctl stop $unit_file
systemctl daemon-reload
systemctl enable $unit_file
systemctl start $unit_file
echo "started service $unit_file"
echo "entering watchdog - hit ^C to return"
sleep 3
watch -n1 systemctl status $unit_file
EOF_INSTALLER


# systemd service unit file
# goes to /etc/systemd/system or so
my $unit_file_template = << "EOF_UF_TPL";
#  see man systemd.service — Service unit configuration
[Unit]
Description=Guntamatic data logger 

Wants=network.target
After=syslog.target network-online.target

[Service]
Type=notify
# NotifyAccess=exec
NotifyAccess=all
User=$username
WorkingDirectory=$setup_dir
# Type=simple
# Type=forking
# ExecStartPost= ... watchdog???
ExecStart=$setup_dir/start.sh
# ExecStart=$base_dir/log2rrd.pl
SyslogIdentifier=guntamatic-logger
Restart=on-failure
RestartSec=20
TimeoutStartSec=180
WatchdogSec=60
# man systemd.kill — Process killing procedure configuration
# KillMode=process
KillMode=control-group
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF_UF_TPL

my $cleanup_template = << "EOF_CLEANUP";
rm -i $unit_file
rm -i install.sh
rm -i cleanup.sh

EOF_CLEANUP

# ~~~~ extract setup goodies and tell what to do next  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~

write_to_filex ($unit_file_template, $unit_file);
chmod 0644, $unit_file;
write_to_filex ($installer_template, 'install.sh');
chmod 0755, 'install.sh';
write_to_filex ($cleanup_template , 'cleanup.sh');
chmod 0755, 'cleanup.sh';

print "\n";
print "setup tools extracted\n";
print "run 'sudo install.sh' or do it manually  \n";
print "optinally may run 'cleanup.sh' to remove install tools again \n";



exit ;


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# sub write to file ( $string, $filename)
sub write_to_filex {
	my ($str , $filename) = @_ ;
	open(my $FH, '>', $filename) or die $!;
	print $FH $str;
	close($FH);
	# chmod 0755, $filename;

}


