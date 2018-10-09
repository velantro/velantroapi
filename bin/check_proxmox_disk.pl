#!/usr/bin/perl


use LWP::Simple;
use feature qw(switch say);

use Getopt::Long qw(:config no_ignore_case);
my ($host, $server, $instances);
my $result = GetOptions(
    "H|host=s"        => \$host,
);

#$url = "http://$host/app/exec/exec_switch_command.php?switch_cmd=show registrations";


$output = `ssh root\@$host "df | grep '/dev/mapper/pve-root'" | awk  '{print \$5}'`;
$output =~ s/[\r\n]//g;
$output =~ s/%//;

#warn $output;
$state  = 'DOWN';

if (!$output || $output =~ /null/) {
        $state = 'DOWN';
} else {
    $count = $output;
    if ($count > 20) {
        $state = 'OK';
    } elsif ($count > 10) {
        $state = 'WARN';
    } else {
        $state = 'DOWN';
    }
        
}

given ($state) {
    chomp($state);
    when ($state eq 'OK') { print "OK - $count% free.\n"; exit(0);      }
    when ($state eq 'WARN') { print "WARNING - $count% free\n"; exit(1);      }
    when ($state eq 'DOWN') { print "CRITICAL - $count% free.\n"; exit(2); }
    default { print "UNKNOWN - PBX STATUS.\n"; exit(3); }

}

