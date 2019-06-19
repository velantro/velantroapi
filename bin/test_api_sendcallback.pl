$tenant = shift;
$ext = shift;
$dest = shift;
$port = shift || 8080;

$cookie = "/tmp/velantroapi.txt";
$cmd = "curl -k  -s  -c $cookie \"http://$tenant.velantro.net:$port/api/api2.pl?action=login&&username=api&&password=api123@@\"";
warn $cmd, "\n";
system($cmd);
$cmd = "curl -k  -s  -b $cookie \"http://$tenant.velantro.net:$port/api/api2.pl?action=sendcallback&&ext=$ext&&dest=$dest\"";
warn $cmd, "\n";
system($cmd);
