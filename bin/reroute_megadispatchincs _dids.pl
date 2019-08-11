@dids = qw/
9085836123
9085836164
9085836173
9085836174
9083253838
9085836120
9085836122
9085836121
9085836175
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
 