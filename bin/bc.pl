use IPC::Open3;
local (*Reader, *Writer);
$pid = open2(\*Reader, \*Writer, \*Error, "bc -l");
$sum = 2;
$cmd = 'CLOUDSDK_CONFIG=/var/www/zhongxiang721 /var/www/google-cloud-sdk/bin/gcloud auth login';


#print Writer "$sum * $sum\n";
chomp($sum = <Error>);

close Writer;
close Reader;
close Error;
waitpid($pid, 0);
print "sum is $sum\n";
