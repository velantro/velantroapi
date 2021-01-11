use IPC::Open3;
local (*Reader, *Writer, *Error);
$username = 'zhongxiang721';
$cmd = "CLOUDSDK_CONFIG=/var/www/$username /var/www/google-cloud-sdk/bin/gcloud auth login";
local $| = 1;
$pid = open3(\*Reader, \*Writer, \*Error, $cmd);
$sum = 2;


#print Writer "$sum * $sum\n";
while (<Reader>) {
	print $_;
}

while( <Error>) {
    ($url) = $_ =~ /(https:.+)\n/;
    if ($url) {
        print $url;
        last;
    }
    
}

if ($url) {
    $outfile = "/tmp/googleauth/$username.out";
	while (1) {	
		if (-s $outfile) {
			open FH, $outfile;
			while (<FH>) {
				chomp;
				$code .= $_;
			}
			print "write $code ...\n";
			print Write $code."\n";
			
			
			
			while (<Error>) {
				print $_;
			}
			unlink $outfile;
			print "Done!\n";
			last;
		} else {
			print "$outfile not found, wait 5 secs ..\n";
			sleep 5;
		}
	}
}

close Writer;
close Reader;
close Error;
waitpid($pid, 0);
