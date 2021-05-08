@lines = qw{
****/mnt/wasabi/var/lib/freeswitch/recordings/beatwaycargo.velantro.net/archive/2021/Apr
****/mnt/wasabi/var/lib/freeswitch/recordings/megadispatchincs.velantro.net/archive/2021/May
****/mnt/wasabi/var/lib/freeswitch/recordings/mgline.velantro.net/archive/2021/Apr
****/mnt/wasabi/var/lib/freeswitch/recordings/mslogistics.velantro.net/archive/2021/Apr
****/mnt/wasabi/var/lib/freeswitch/recordings/onelogisticsnetwork.velantro.net/archive/2021/May
****/mnt/wasabi/var/lib/freeswitch/recordings/tsa.velantro.net/archive/2021/May
****/mnt/wasabi/usr/local/freeswitch/recordings/itftrucking.velantro.net/archive/2020/Jan
****/mnt/wasabi/usr/local/freeswitch/recordings/itftrucking.velantro.net/archive/2020/Feb
****/mnt/wasabi/usr/local/freeswitch/recordings/itftrucking.velantro.net/archive/2020/Mar
****/mnt/wasabi/usr/local/freeswitch/recordings/itftrucking.velantro.net/archive/2020/May
****/mnt/wasabi/usr/local/freeswitch/recordings/itftrucking.velantro.net/archive/2020/Jun
****/mnt/wasabi/usr/local/freeswitch/recordings/itftrucking.velantro.net/archive/2020/Jul
****/mnt/wasabi/usr/local/freeswitch/recordings/itftrucking.velantro.net/archive/2020/Sep
****/mnt/wasabi/usr/local/freeswitch/recordings/itftrucking.velantro.net/archive/2020/Oct
****/mnt/wasabi/usr/local/freeswitch/recordings/itftrucking.velantro.net/archive/2020/Nov
****/mnt/wasabi/usr/local/freeswitch/recordings/itftrucking.velantro.net/archive/2021/Jan
****/mnt/wasabi/usr/local/freeswitch/recordings/itftrucking.velantro.net/archive/2021/Feb
****/mnt/wasabi/usr/local/freeswitch/recordings/itftrucking.velantro.net/archive/2021/Mar
****/mnt/wasabi/usr/local/freeswitch/recordings/jlpdispatching.velantro.net/archive/2021/Jan
****/mnt/wasabi/usr/local/freeswitch/recordings/jlpdispatching.velantro.net/archive/2021/Feb
****/mnt/wasabi/usr/local/freeswitch/recordings/jlpdispatching.velantro.net/archive/2021/Mar
****/mnt/wasabi/usr/local/freeswitch/recordings/jnettrans.velantro.net/archive/2021/May
****/mnt/wasabi/usr/local/freeswitch/recordings/judicialguardllp.velantro.net/archive/2021/Jan
****/mnt/wasabi/usr/local/freeswitch/recordings/judicialguardllp.velantro.net/archive/2021/Feb
****/mnt/wasabi/usr/local/freeswitch/recordings/judicialguardllp.velantro.net/archive/2021/Mar
****/mnt/wasabi/usr/local/freeswitch/recordings/juicywingzinc.velantro.net/archive/2021/Jan
****/mnt/wasabi/usr/local/freeswitch/recordings/juicywingzinc.velantro.net/archive/2021/Feb
****/mnt/wasabi/usr/local/freeswitch/recordings/juicywingzinc.velantro.net/archive/2021/Mar
****/mnt/wasabi/usr/local/freeswitch/recordings/justelitetransport.velantro.net/archive/2021/Jan
****/mnt/wasabi/usr/local/freeswitch/recordings/justelitetransport.velantro.net/archive/2021/Feb
****/mnt/wasabi/usr/local/freeswitch/recordings/justelitetransport.velantro.net/archive/2021/Mar
};

$raw = `cat raw3.log`;
@lines = split /\n/, $raw;
print "#!/bin/sh\n";
for $e (@lines) {
   chomp;
   ($p, $d, $y, $m, $day) = $e =~ m{\*\*\*/mnt/wasabi/(.+?)/freeswitch/recordings/(.+)/archive/(\d+)/(\w+)/(\d+)$};
   $cmd = "cp -purfn /mnt/s3/$p/freeswitch/recordings/$d/archive/$y/$m/$day /mnt/wasabi/$p/freeswitch/recordings/$d/archive/$y/$m &";
   print $cmd, "\n";
}