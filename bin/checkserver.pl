$lines = '
67.227.80.76,22,76.velantro.net,http://76.velantro.net/
67.227.80.67,22,67.velantro.net,http://67.227.80.67/
67.227.80.83,22,204.velantro.net,http://204.velantro.net/
67.227.80.51,56443,19.velantro.net,http://19.velantro.net/
67.227.80.35,56443,243.velantro.net,http://243.velantro.net/
67.227.80.37,56443,245.velantro.net,http://245.velantro.net
208.76.253.123,56443,vip,http://vip.velantro.net
67.207.164.220,56443,220.velantro.net,http://220.velantro.net
67.227.80.53,22,67.227.80.53,http://67.227.80.53
67.227.80.55,22,67.227.80.55,http://67.227.80.55/
67.227.80.56,22,67.227.80.56,http://67.227.80.56
67.227.80.20,22,velantro20,http://67.227.80.20
208.76.253.122,22,velantro122,http://208.76.253.122/
208.76.253.119,22,shy,http://ml.managedlogix.net
67.227.80.11,56443,ml2,http://newmentor.managedlogix.net/
67.227.80.10,56443,ml3,http://67.227.80.10
67.227.80.36,56443,liv,http://liv.livvoip.net
67.227.80.22,22,liv2,http://67.227.80.22/
67.227.80.21,22,serv1,http://67.227.80.21/
67.227.80.23,22,serv2,http://67.227.80.23/
67.207.164.219,22,multicomm,http://67.207.164.219/
';

for (split /\n/, $lines) {
	($ip,$port,$name,$uri) = split ',', $_, 4;
	next if !$ip;
	print "check $name [$ip:$port]\n";
	$cmd = "ssh -p $port root\@$ip  \"df -hl | grep '/\$' | awk '{print \$2}'\"";
	#warn $cmd;
	system($cmd);
	$cmd = "ssh -p $port root\@$ip  \"df -h | grep 's3' \"";
	#warn $cmd;
	system($cmd);
     $cmd = "ssh -p $port root\@$ip  \"fs_cli -rx 'show registrations'\" | tail -2 | head -1";
     system($cmd);
#	print "\n";
    $cmd = "curl  -I -k -m 3 -s '$uri' | head -1";
    system($cmd);
    print "\n";
	 $cmd = "sipsak -vv -s sip:100\@$ip | grep '  SIP/2.0 200 OK'";
    system($cmd);
    print "\n---------------------------------------\n";
	
}
