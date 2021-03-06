@base_dir = ('var/lib/freeswitch', 'usr/local/freeswitch');

for $b (@base_dir) {
   while (</mnt/s3/$b/recordings/*>) {
      #print $_, "\n";
      ($domain) = $_ =~ m{recordings/(.+)$};
      #print $d, "\n";
      if ((!-d "/mnt/wasabi/$b/recordings/$domain")) {
         print "******/mnt/wasabi/$b/recordings/$domain not found\n";
         next;
      }
      for $y (2020 .. 2021) {
         if ((!-d "/mnt/s3/$b/recordings/$domain/archive/$y")) {
            warn "/mnt/s3/$b/recordings/$domain/archive/$y not found\n";
            next;
         }
         if ((!-d "/mnt/wasabi/$b/recordings/$domain/archive/$y")) {
            print "*****/mnt/wasabi/$b/recordings/$domain/archive/$y not found\n";
            next;
         }
         
         if ($y eq '2021') {
            @months = qw/Jan  Feb  Mar  Apr  May/;
         } else {
            @months = qw/Jan  Feb  Mar  Apr  May  Jun  Jul  Aug  Sep  Oct  Nov  Dec/;
         }
         
         for $m(@months) {
            if ((!-d "/mnt/s3/$b/recordings/$domain/archive/$y/$m")) {
               warn "/mnt/s3/$b/recordings/$domain/archive/$y/$m not found\n";
               next;
            }
            if ((!-d "/mnt/wasabi/$b/recordings/$domain/archive/$y/$m")) {
               print "****/mnt/wasabi/$b/recordings/$domain/archive/$y/$m not found\n";
               next;
            }
            for $d (1..31) {
               $d = sprintf("%02d", $d);
               if ((!-d "/mnt/s3/$b/recordings/$domain/archive/$y/$m/$d")) {
                  warn "/mnt/s3/$b/recordings/$domain/archive/$y/$m/$d not found\n";
                  next;
               }
               if ((!-d "/mnt/wasabi/$b/recordings/$domain/archive/$y/$m/$d")) {
                  print "***/mnt/wasabi/$b/recordings/$domain/archive/$y/$m/$d not found\n";
                  next;
               }
            }
         }
      }
   }   
}
