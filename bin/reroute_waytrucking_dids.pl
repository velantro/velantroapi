@dids = qw/
6263131300
3234735774
7472074144
6264359560
9093233222
4242181318
9514356005
5623592600
7472403696
 /;
 
my %config = ();
my $txt = `cat /etc/fb.conf`;

for (split /\n/, $txt) {
    my ($key, $val)     = split /=/, $_, 2;

    if ($key) {
        $config{$key} = $val;
        warn "$key=$val\n";
    }
}
$ip = "208.76.253.124";
 for $d (@dids) {
    $url = "https://api.vitelity.net/api.php?login=$config{api_user}&pass=$config{api_pass}&cmd=reroute&routesip=$ip&did=$d";
    #$res = `curl -k '$url'`;
    warn $url;
 }
 