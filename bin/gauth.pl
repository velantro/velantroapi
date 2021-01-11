use IPC::Open3;
local (*Reader, *Writer, *Error);
$username = 'zhongxiang721';
$cmd = "CLOUDSDK_CONFIG=/var/www/$username /var/www/google-cloud-sdk/bin/gcloud auth login";
local $| = 1;
$pid = open3(\*Reader, \*Writer, \*Error, $cmd);
$sum = 2;


#print Writer "$sum * $sum\n";
while( <Error>) {
    ($url) = $_ =~ /(https:.+)\n/;
    if ($url) {
        print $url;
        last;
    }
    
}

if ($url) {
    $outfile = "/tmp/googleauth/$username.out";           
    if (-s $file) {
		open FH, $outfile;
		while (<FH>) {
			chomp;
			$code .= $_;
		}
		print "write $code ...\n";
		print Write $code."\n";
		
		while (<READER) {
			print $_;
		}
		
		while (<ERROR>) {
			print $_;
		}
		
		print "Done!\n";
		
    } else {
		print "$outfile not found, wait 5 secs ..\n";
		sleep 5;
	}   
}

close Writer;
close Reader;
close Error;
waitpid($pid, 0);
print "sum is $sum\n";
