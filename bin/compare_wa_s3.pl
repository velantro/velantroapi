@base_dir = ('var/lib/freeswitch', 'usr/local/freeswitch');

for $b (@base_dir) {
   while (</mnt/s3/$b/recordings/*>) {
      #print $_, "\n";
      ($d) = $_ =~ m{recordings/(.+)$};
      #print $d, "\n";
      if ((!-d "/mnt/wasabi/$b/recordings/$d")) {
         print "******/mnt/wasabi/$b/recordings/$d not found\n";
         next;
      }
      for $y (2020 .. 2021) {
         if ((!-d "/mnt/s3/$b/recordings/$d/$y")) {
            warn "/mnt/s3/$b/recordings/$d/$y not found\n";
            next;
         }
         if ((!-d "/mnt/wasabi/$b/recordings/$d/$y")) {
            print "*****/mnt/wasabi/$b/recordings/$d/$y not found\n";
            next;
         }
         
         if ($y eq '2021') {
            @months = qw/Jan  Feb  Mar  Apr  May/;
         } else {
            @months = qw/Jan  Feb  Mar  Apr  May  Jun  Jul  Aug  Sep  Oct  Nov  Dec/;
         }
         
         for $m(@months) {
            if ((!-d "/mnt/s3/$b/recordings/$d/$y/$m")) {
               warn "/mnt/s3/$b/recordings/$d/$y/$m not found\n";
               next;
            }
            if ((!-d "/mnt/wasabi/$b/recordings/$d/$y/$m")) {
               print "****/mnt/wasabi/$b/recordings/$d/$y/$m not found\n";
               next;
            }
            for $d (1..31) {
               $d = sprintf("%02d", $d);
               if ((!-d "/mnt/s3/$b/recordings/$d/$y/$m/$d")) {
                  warn "/mnt/s3/$b/recordings/$d/$y/$m/$d not found\n";
                  next;
               }
               if ((!-d "/mnt/wasabi/$b/recordings/$d/$y/$m/$d")) {
                  print "***/mnt/wasabi/$b/recordings/$d/$y/$m/$d not found\n";
                  next;
               }
            }
         }
      }
   }   
}
