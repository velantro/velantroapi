
@arr = localtime();
$current_hour = $arr[2];
$stop_hour = 6;
if ($current_hour >= 20) {
   $run_seconds = (24-$current_hour+5)*3600;
} elsif($current_hour <6) {
   $run_seconds = (5-$current_hours)*3600;
} else {
   warn "Please Run it after 20pm and before 6am!\n";
   exit;
}

$s = '/usr/local/freeswitch/recordings/';
if (not -d $s) {
   $s = "/var/lib/freeswitch/recordings/";
}


if (!-e "/mnt/s3/iams3") {
    warn "not found /mnt/s3/iams3, let's mount it!\n";
    system("/salzh/bin/mounts3");
    
    if (!-e "/mnt/s3/iams3") {
      warn "Fail to mount s3!\n";
      exit 0;
    }
}


$start_time = time;
for $f (split /\n/, `find $s -type f -mtime +3 -name "*.wav"  | grep  'archive'`) {
   if (time - $start_time > $run_seconds) {
      warn "Time Reached, Exit!\n";
      system("umount -f /mnt/s3; umount -f /mnt/s3");
      exit;
   }
   
   warn "mv $f\n";
   next if -l $f;
   ($dir, $n) = $f =~ /(.+)\/(.+\.wav)$/;

   $destdir = "/mnt/s3$dir";
   if (!-d $destdir) {
       system("mkdir -p $destdir");

   }

   if (!-e "/mnt/s3/iams3") {
      warn "not found /mnt/s3/iams3, exit!\n";
      exit;
   }
   
   warn "copy $f to $destdir\n";
   system("mv $f $destdir");

   warn "ln -s $destdir/$n $f";
   system("ln -s $destdir/$n $f");
   system("chmod a+r $destdir/$n");

}
system("umount -f /mnt/s3; umount -f /mnt/s3");