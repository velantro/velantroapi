
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
for $f (split /\n/, `find $s -type f -mtime +3 -name "*.wav"  | grep  'archive'`) {
        warn "mv $f\n";
        next if -l $f;
        ($dir, $n) = $f =~ /(.+)\/(.+\.wav)$/;

        $destdir = "/mnt/s3$dir";
        if (!-d $destdir) {
            system("mkdir -p $destdir");

        }

        warn "copy $f to $destdir\n";
        system("mv $f $destdir");

        warn "ln -s $destdir/$n $f";
        system("ln -s $destdir/$n $f");
        system("chmod a+r $destdir/$n");

    }
