use JSON;
use LWP::Simple;
use Data::Dumper;
$cookie = "/tmp/api.txt";
$res = `curl -s -k -c $cookie "http://vip.velantro.net:8080/api/api2.pl?action=login&username=api&password=api123@@"`;
#$res = `curl -s -k -b $cookie "http://vip.velantro.net:8080/api/api2.pl?action=sendcallback&ext=188&dest=2124441005&autoanswer=1"`;
$res = `curl -s -k -b $cookie "http://vip.velantro.net:8080/api/api2.pl?action=getcdrbydid&did=8882115404"`;
$hash = decode_json($res);
print Data::Dumper::Dumper($hash);
=pod
$id = $hash->{callbackid};
while (1) {
    $s = `curl -s -k -b $cookie "http://vip.velantro.net:8080/api/api2.pl?action=getcallbackstate&callbackid=$id"`;
    print $s, "\n";
}
=cut



