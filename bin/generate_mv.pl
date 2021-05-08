@lines = qw{
******/mnt/wasabi/var/lib/freeswitch/recordings/getrightlogistics.velantro.net
******/mnt/wasabi/var/lib/freeswitch/recordings/helpinghands2048w238.nexlevel2.net
******/mnt/wasabi/var/lib/freeswitch/recordings/krftdsushi.nexeravoice.net
******/mnt/wasabi/var/lib/freeswitch/recordings/larisins.nexeravoice.net
******/mnt/wasabi/var/lib/freeswitch/recordings/legalservice.nexeravoice.net
******/mnt/wasabi/var/lib/freeswitch/recordings/level2security.nexeravoice.net
******/mnt/wasabi/var/lib/freeswitch/recordings/mmcarstruckvans.nexeravoice.net
******/mnt/wasabi/var/lib/freeswitch/recordings/mprfunding.nexeravoice.net
******/mnt/wasabi/var/lib/freeswitch/recordings/navarettefinancial.nexeravoice.net
******/mnt/wasabi/var/lib/freeswitch/recordings/nexera.nexeravoice.net
******/mnt/wasabi/var/lib/freeswitch/recordings/plesrv1.nexeravoice.net
******/mnt/wasabi/var/lib/freeswitch/recordings/royalprestige.nexeravoice.net
******/mnt/wasabi/var/lib/freeswitch/recordings/sdas.nexeravoice.net
******/mnt/wasabi/var/lib/freeswitch/recordings/solarclean.nexeravoice.net
};

for $e (@lines) {
   ($d) = $e =~ m{\*\*\*\*\*\*/mnt/wasabi/var/lib/freeswitch/recordings/(.+)$};
   $cmd = "setsid cp -purfn /mnt/s3/var/lib/freeswitch/recordings/$d /mnt/wasabi/var/lib/freeswitch/recordings";
   print $cmd, "\n";
}