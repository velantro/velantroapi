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
                
    if (-s "/tmp/googleauth/$username.out") {
       open(FH, ""
    }
    
}

close Writer;
close Reader;
close Error;
waitpid($pid, 0);
print "sum is $sum\n";
