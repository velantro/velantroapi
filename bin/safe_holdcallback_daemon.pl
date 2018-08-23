
$daemon_script = "/salzh/velantroapi/bin/app_konference.listener.pl";
	
while (1) {
	system("perl $daemon_script > /tmp/h.log 2>&1");
	warn "\n\n!!!!!!!!!!!!!!!!!!!\n convert_daemon stop,let's restart it\n\n";
	
	sleep 2;
}

