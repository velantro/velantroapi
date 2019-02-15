if (-e "/root/recordings_old.txt") {
   $file = "/root/recordings_old.txt";
}

$file ||= "/root/recordings_new.txt";

if (!-e $file) {
   die "recording file not found!\n";
}
$txt = `cat $file`;
for  (split /\n/, $txt) {
   chomp;
   ($size, $t) = split /\s+/, $_, 2;
   print "#$size==>$t!\n";
   next if $t eq "/mnt/s3/var/lib/freeswitch/recordings/tsa.velantro.net";
   next if $t eq "/mnt/s3/var/lib/freeswitch/recordings/onelogisticsnetwork.velantro.net";
   next if $t eq "/mnt/s3/var/lib/freeswitch/recordings/rapidins.velantro.net";
   print "rm -rf  $t/archive/2015\n";
   print "rm -rf  $t/archive/2016\n";
   print "rm -rf  $t/archive/2017\n";
   print "rm -rf  $t/archive/2018/Jan\n";
   print "rm -rf  $t/archive/2018/Feb\n";
   print "rm -rf  $t/archive/2018/Mar\n";
   print "rm -rf  $t/archive/2018/Apr\n";
   print "rm -rf  $t/archive/2018/May\n";
   print "rm -rf  $t/archive/2018/Jun\n";

}


