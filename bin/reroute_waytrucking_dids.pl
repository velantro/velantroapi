@dids = qw/
8183220542
8774779677
6303814660
3143968588
3146955009
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
$ip = "67.227.80.71";
 for $d (@dids) {
    $url = "https://api.vitelity.net/api.php?login=$config{api_user}&pass=$config{api_pass}&cmd=reroute&routesip=$ip&did=$d";
    #$res = `curl -k '$url'`;
    warn $url;
 }
 