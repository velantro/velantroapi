@dids = qw/
2133206444
3233065474
7472074004
4242181303
9492011024
7472026686
2132123078
8558706482
9092031805
4242181311
9512087241
7472375222
9093233222
2132127383
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
$ip = "67.227.80.12";
 for $d (@dids) {
    $url = "https://api.vitelity.net/api.php?login=$config{api_user}&pass=$config{api_pass}&cmd=reroute&routesip=$ip&did=$d";
    #$res = `curl -k '$url'`;
    warn $url;
 }
 