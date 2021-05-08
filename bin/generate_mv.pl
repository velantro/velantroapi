@lines = qw{
******/mnt/wasabi/var/lib/freeswitch/recordings/getrightlogistics.velantro.net not found
******/mnt/wasabi/var/lib/freeswitch/recordings/helpinghands2048w238.nexlevel2.net not found
******/mnt/wasabi/var/lib/freeswitch/recordings/krftdsushi.nexeravoice.net not found
******/mnt/wasabi/var/lib/freeswitch/recordings/larisins.nexeravoice.net not found
******/mnt/wasabi/var/lib/freeswitch/recordings/legalservice.nexeravoice.net not found
******/mnt/wasabi/var/lib/freeswitch/recordings/level2security.nexeravoice.net not found
******/mnt/wasabi/var/lib/freeswitch/recordings/mmcarstruckvans.nexeravoice.net not found
******/mnt/wasabi/var/lib/freeswitch/recordings/mprfunding.nexeravoice.net not found
******/mnt/wasabi/var/lib/freeswitch/recordings/navarettefinancial.nexeravoice.net not found
******/mnt/wasabi/var/lib/freeswitch/recordings/nexera.nexeravoice.net not found
******/mnt/wasabi/var/lib/freeswitch/recordings/plesrv1.nexeravoice.net not found
******/mnt/wasabi/var/lib/freeswitch/recordings/royalprestige.nexeravoice.net not found
******/mnt/wasabi/var/lib/freeswitch/recordings/sdas.nexeravoice.net not found
******/mnt/wasabi/var/lib/freeswitch/recordings/solarclean.nexeravoice.net not found
};

for $e (@lines) {
   ($d) = $e =~ m{\*\*\*\*\*\*/mnt/wasabi/var/lib/freeswitch/recordings/(.+?) not found};
   $cmd = "setsid cp -purfn /mnt/s3/var/lib/freeswitch/recordings/$d /mnt/wasabi/var/lib/freeswitch/recordings";
   print $cmd, "\n";
}