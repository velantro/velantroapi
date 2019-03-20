use JSON;
use LWP::Simple;
use Data::Dumper;
$res = get "http://vip.velantro.net:8080/api/api2.pl?action=sendcallback&ext=188&dest=2124441005";
my $hash = decode_json($res);
print Data::Dumper::Dumper($hash);



