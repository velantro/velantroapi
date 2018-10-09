#!/usr/bin/perl


use LWP::Simple;
use feature qw(switch say);

use Getopt::Long qw(:config no_ignore_case);
my ($host, $server, $instances);
my $result = GetOptions(
    "H|host=s"        => \$host,
);

#$url = "http://$host/app/exec/exec_switch_command.php?switch_cmd=show registrations";



$output = `sipsak  -vv -s sip:100\@$host | tail -3`;

$output =~ s/[\r\n]/,/g;

#warn $output;
$state  = 'DOWN';

if (!$output || $output =~ /null/) {
        $state = 'DOWN';
} else {
    if ($output =~ /200 OK/) {
        $state = 'OK';
    } else {
        $state = 'WARN';
    }
}

given ($state) {
    chomp($state);
    when ($state eq 'OK') { print "OK - $output\n"; exit(0);      }
    when ($state eq 'WARN') { print "WARNING - $output\n"; exit(1);      }
    when ($state eq 'DOWN') { print "CRITICAL - $output.\n"; exit(2); }
    default { print "UNKNOWN - SIP STATUS.\n"; exit(3); }

}