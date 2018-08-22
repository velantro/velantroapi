
$s = '/usr/local/freeswitch/recordings/';
if (not -d $s) {
   $s = "/var/lib/freeswitch/recordings/";
}

if (!-e "/mnt/s3/iams3") {
    die "not found /mnt/s3/iams3";
}
for $f (split /\n/, `find $s -mtime +7 -name "*.wav"  | grep  'archive'`) {
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

    }
