@dids = qw/
6093185661
6094872211
8002339394
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
$ip = "67.227.80.58";
 for $d (@dids) {
    $url = "https://api.vitelity.net/api.php?login=$config{api_user}&pass=$config{api_pass}&cmd=reroute&routesip=$ip&did=$d";
    #$res = `curl -k '$url'`;
    warn $url;
 }
 