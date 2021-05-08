@lines = qw{
*****/mnt/wasabi/var/lib/freeswitch/recordings/rlgstaterealty.velantro.net/archive/2021
*****/mnt/wasabi/usr/local/freeswitch/recordings/jlpdispatching.velantro.net/archive/2020
*****/mnt/wasabi/usr/local/freeswitch/recordings/judicialguardllp.velantro.net/archive/2020
*****/mnt/wasabi/usr/local/freeswitch/recordings/juicywingzinc.velantro.net/archive/2020
*****/mnt/wasabi/usr/local/freeswitch/recordings/justelitetransport.velantro.net/archive/2020
};

print "#!/bin/sh\n";
for $e (@lines) {
   ($p, $d, $y) = $e =~ m{\*\*\*\*\*/mnt/wasabi/(.+?)/freeswitch/recordings/(.+)/archive/(\d+)$};
   $cmd = "cp -purfn /mnt/s3/$p/freeswitch/recordings/$d/archive/$y /mnt/wasabi/$p/freeswitch/recordings/$d/archive &";
   print $cmd, "\n";
}