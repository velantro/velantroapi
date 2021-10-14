$lines = '
67.227.80.76,22,velantro76,http://76.velantro.net/,pbxv1
67.227.80.67,22,velantro67,http://67.227.80.67/,pbxv1
67.227.80.71,22,velantro71,http://67.227.80.71/,pbxv1
67.227.80.83,22,velantro204,http://204.velantro.net/,pbxv1
67.227.80.51,56443,velantro19,http://19.velantro.net/,pbxv1
67.227.80.35,56443,velantro243,http://243.velantro.net/,pbxv1
67.227.80.37,56443,velantro245,http://245.velantro.net,pbxv1
208.76.253.123,56443,velantrovip,http://vip.velantro.net,pbxv1
67.207.164.220,56443,velantro220,http://220.velantro.net,pbxv1
67.227.80.53,22,velantro53,http://67.227.80.53,pbxv1
67.227.80.55,22,velantro55,http://67.227.80.55/,pbxv2
67.227.80.56,22,velantro56,http://67.227.80.56,pbxv2
67.227.80.20,22,velantro20,http://67.227.80.20,pbxv2
67.227.80.12,22,velantro12,http://67.227.80.12,pbxv2
67.227.80.6,22,velantro6,http://67.227.80.6,pbxv2
208.76.253.122,22,velantro122,http://208.76.253.122/,pbxv2
208.76.253.124,22,velantrogbm,http://gbmllc.velantro.net/,pbxv2
208.76.253.121,22,velantro121,http://208.76.253.121/,pbxv2
208.76.253.116,22,velantro116,http://208.76.253.116/,pbxv2
208.76.253.115,22,velantro115,http://208.76.253.115/,pbxv2
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
} elsif ($cmd eq 'velantroupdatesmtp') {
		$pass = shift || die "no new pass!\n";
		for (split /\n/, $lines) {
			($ip,$port,$name,$uri) = split ',', $_, 4;
			next if !$ip;
			next unless $name =~ /velantro/;
			print "$cmd on  $name [$ip:$port]\n";

			#$cmd = "echo \"update v_default_settings set default_setting_value=\\'$pass\\' where  default_setting_subcategory=\\'smtp_password\\'\" | psql fusionpbx -U fusionpbx -h 127.0.0.1";
			#print $cmd, "\n";
			system("ssh -t -p $port root\@$ip sh /var/www/api/bin/updatesmtppass.sh $pass");
		}
} elsif ($cmd eq 'velantroinstallssl') {
		for (split /\n/, $lines) {
			($ip,$port,$name,$uri) = split ',', $_, 4;
			next if !$ip;
			next unless $name =~ /velantro/;
			print "$cmd on  $name [$ip:$port]\n";

			$cmd = "scp -oPort=$port /etc/ssl/private/nginx.key $ip:/etc/ssl/private/nginx.key";
			warn $cmd, "\n";
			system($cmd);
			
			$cmd = "scp -oPort=$port /etc/ssl/certs/nginx.crt $ip:/etc/ssl/certs/nginx.crt";
			warn $cmd, "\n";
			system($cmd);
			
			system("ssh -t -p $port root\@$ip /etc/init.d/nginx restart");
		}
} elsif ($cmd eq 'showcalls') {
		for (split /\n/, $lines) {
			($ip,$port,$name,$uri) = split ',', $_, 4;
			next if !$ip;
			print "$cmd on  $name [$ip:$port]\n";
			
			system("ssh -p $port root\@$ip 'fs_cli -rx \"show calls\" | wc -l'");
		}
} elsif ($cmd eq 'checktollfree') {
		$mon = shift;
		$emon =  shift;
		for (split /\n/, $lines) {
			($ip,$port,$name,$uri) = split ',', $_, 4;
			next if !$ip;
			next unless $name =~ /velantro/;
			print "$cmd on  $name [$ip:$port]\n";

			
			system("ssh -t -p $port root\@$ip sh /var/www/api/bin/check_toll_free.sh $mon $emon");
		}
} elsif ($cmd eq 'checkos') {
		$mon = shift;
		$emon =  shift;
		for (split /\n/, $lines) {
			($ip,$port,$name,$uri) = split ',', $_, 4;
			next if !$ip;
			print "$cmd on  $name [$ip:$port]\n";

			
			system("ssh -t -p $port root\@$ip cat /etc/debian_version");
		}
} elsif ($cmd eq 'updatewasabipass') {
	
	for (split /\n/, $lines) {
		($ip,$port,$name,$uri,$v) = split ',', $_, 5;
		next if !$ip;
		next unless $name =~ /velantro/;
		print "$cmd on  $name [$ip:$port]\n";
		
		system("scp -oPort=$port /etc/passwd-wasabi root\@$ip:/etc");
	}
}  elsif ($cmd eq 'updatewasabi') {
	
	for (split /\n/, $lines) {
		($ip,$port,$name,$uri,$v) = split ',', $_, 5;
		next if !$ip;
		next unless $v eq 'pbxv1';
		print "$cmd on  $name [$ip:$port]\n";
		
		system("scp -oPort=$port /salzh/bin/mounts3 root\@$ip:/salzh/bin");
		system("scp -oPort=$port /usr/local/bin/s3fsnew root\@$ip:/usr/local/bin/");
	}
} elsif ($cmd eq 'updatewasabi2') {
	
	for (split /\n/, $lines) {
		($ip,$port,$name,$uri,$v) = split ',', $_, 5;
		next if !$ip;
		next unless $v eq 'pbxv2';
		print "$cmd on  $name [$ip:$port]\n";
		
		system("scp -oPort=$port /salzh/bin/mounts3 root\@$ip:/salzh/bin");
		system("ssh -t -p $port root\@$ip cp -f /usr/local/bin/s3fs /usr/local/bin/s3fsnew");
	}
} elsif ($cmd eq 'updatewasabi3') {
	
	for (split /\n/, $lines) {
		($ip,$port,$name,$uri,$v) = split ',', $_, 5;
		next if !$ip;
		next unless $name =~ /velantro/;
		next if $name eq 'velantrovip' || $name eq 'velantro118';
		print "$cmd on  $name [$ip:$port]\n";
		
		system("scp -oPort=$port /salzh/bin/mountwasabi root\@$ip:/salzh/bin/mounts3");
	}
}  elsif ($cmd eq 'checkcoredb') {
		for (split /\n/, $lines) {
			($ip,$port,$name,$uri) = split ',', $_, 4;
			next if !$ip;
			print "$cmd on  $name [$ip:$port]\n";
			
			system("ssh -t -p $port root\@$ip \"grep 'SQL ERR' /usr/local/freeswitch/log/freeswitch.log\"");
			system("ssh -t -p $port root\@$ip \"grep 'SQL ERR' /var/log/freeswitch/freeswitch.log\"");
		}
}  elsif ($cmd eq 'reloadacl') {
		for (split /\n/, $lines) {
			($ip,$port,$name,$uri) = split ',', $_, 4;
			next if !$ip;
			print "$cmd on  $name [$ip:$port]\n";
			
			system("ssh -t -p $port root\@$ip \"fs_cli -rx 'reloadacl'\"");
		}
}
 else {
	for (split /\n/, $lines) {
		($ip,$port,$name,$uri) = split ',', $_, 4;
		next if !$ip;
		print "$cmd on  $name [$ip:$port]\n";
		
		system("ssh -t -p $port root\@$ip \"$cmd\"");
	}
}