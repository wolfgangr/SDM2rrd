#!/usr/bin/perl
#
# https://askubuntu.com/questions/645/how-do-you-reset-a-usb-device-from-the-command-line
# compile `usbreset.c`provided there and make it executable, eg in /usr/local/lib
# tested with dongle at one extra hub, not testet at other nesting level
#
use warnings;
use strict;
use Cwd;

my $dev_link = shift @ARGV or die "usage: $0 devicefile ";

my $usbreset = `which usbreset` or die " cannot find usbreset"; 
chomp $usbreset ;

# the challenge is to climb down the device tree

my $realpath = Cwd::abs_path($dev_link ); 
# print "\$realpath: $realpath\n";

# _$ udevadm info /dev/serial/by-id/usb-1a86_USB2.0-Serial-if00-port0 | grep DEVPATH
my $tty_devpath = `udevadm info $realpath  | grep DEVPATH` ;
# print "\$tty_devpath: $tty_devpath\n";

#       E: DEVPATH=/devices/pci0000:00/0000:00:12.0/usb4/4-5/4-5:1.0/ttyUSB1/tty/ttyUSB1
$tty_devpath =~ /^(E: DEVPATH=)(.+)$/ or die "cannot parse $tty_devpath";
my $usb_devpath = '/sys' . $2 . '/device/../..';   # this is the quirk
# print "\$usb_devpath: $usb_devpath\n";
my $usb_devp_a = Cwd::abs_path($usb_devpath);
# print "\$usb_devp_a: $usb_devp_a\n";



# _$ udevadm info /sys/devices/pci0000:00/0000:00:12.0/usb4/4-5/ | grep DEVNAME
my $usb_devname = `udevadm info $usb_devpath | grep DEVNAME`;
# print "\$usb_devname: $usb_devname\n";

#       E: DEVNAME=/dev/bus/usb/004/008
$usb_devname =~ /^(E: DEVNAME=)(.+)$/ or die "cannot parse $usb_devname";
my $resettable = $2;
print "\$resetting USB device: $resettable\n";

# config this command for using sudo wo/ pwd
system (" sudo $usbreset  $resettable ");


