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
67.227.80.12,22,velantro12,http://67.227.80.12
208.76.253.122,22,velantro122,http://208.76.253.122/
208.76.253.121,22,velantro121,http://208.76.253.121/
208.76.253.116,22,velantro116,http://208.76.253.116/
208.76.253.115,22,velantro115,http://208.76.253.115/
208.76.253.118,22,velantro118,http://208.76.253.118/
208.76.253.119,22,shy,http://ml.managedlogix.net
67.227.80.11,56443,ml2,http://newmentor.managedlogix.net/
67.227.80.10,56443,ml3,http://67.227.80.10
67.227.80.36,56443,liv,http://liv.livvoip.net
67.227.80.22,22,liv2,http://67.227.80.22/
67.227.80.21,22,serv1,http://67.227.80.21/
67.227.80.23,22,serv2,http://67.227.80.23/
67.227.80.26,22,gosimplevoice,http://http://serv1.gosimplevoice.net/
67.207.164.219,22,multicomm,http://67.207.164.219/
';

$cmd = shift || exit;
if ($cmd eq 'updatemonitorscript') {
	
	for (split /\n/, $lines) {
		($ip,$port,$name,$uri) = split ',', $_, 4;
		next if !$ip;
		print "$cmd on  $name [$ip:$port]\n";
		
		system("scp -oPort=$port /salzh/velantroapi/bin/exec_monitor_command.php root\@$ip:/var/www/fusionpbx/app/exec/exec_monitor_command.php")

	}
} elsif ($cmd eq 'updatefirewallscript') {
		for (split /\n/, $lines) {
			($ip,$port,$name,$uri) = split ',', $_, 4;
			next if !$ip;
			print "$cmd on  $name [$ip:$port]\n";
			
			system("scp -oPort=$port /salzh/velantroapi/bin/firewall2.pl root\@$ip:/var/www/");
		}
} elsif ($cmd eq 'updatefirewall') {
		for (split /\n/, $lines) {
			($ip,$port,$name,$uri) = split ',', $_, 4;
			next if !$ip;
			print "$cmd on  $name [$ip:$port]\n";
			
			system("ssh -p $port root\@$ip 'perl /var/www/firewall2.pl'");
		}
} elsif ($cmd eq 'updateindexhtml') {
		for (split /\n/, $lines) {
			($ip,$port,$name,$uri) = split ',', $_, 4;
			next if !$ip;
			print "$cmd on  $name [$ip:$port]\n";
			
			system("scp -oPort=$port /var/www/fusionpbx/index.html root\@$ip:/var/www/fusionpbx");
		}
} elsif ($cmd eq 'codeupdate') {
		for (split /\n/, $lines) {
			($ip,$port,$name,$uri) = split ',', $_, 4;
			next if !$ip;
			print "$cmd on  $name [$ip:$port]\n";
			
			system("ssh -t -p $port root\@$ip 'cd /salzh/velantroapi/ && git pull'");
		}
} elsif ($cmd eq 'updatesmtp') {
		$pass = shift || die "no new pass!\n";
		for (split /\n/, $lines) {
			($ip,$port,$name,$uri) = split ',', $_, 4;
			next if !$ip;
			print "$cmd on  $name [$ip:$port]\n";
			
			system("ssh -t -p $port root\@$ip 'echo \"update v_default_settings set default_setting_value=\'$pass\' where  default_setting_subcategory=\'smtp_password\'\" | psql fusionpbx -U fusionpbx -h 127.0.0.1");
		}
}
