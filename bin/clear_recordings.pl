@base_dir = ('var/lib/freeswitch', 'usr/local/freeswitch');

for $b (@base_dir) {
   while (</mnt/s3/$b/recordings/*>) {
      #print $_, "\n";
      ($domain) = $_ =~ m{recordings/(.+)$};
      #print $d, "\n";
      
      
      
      
      for $y (2020 .. 2021) {
         if ((!-d "/mnt/s3/$b/recordings/$domain/archive/$y")) {
            warn "/mnt/s3/$b/recordings/$domain/archive/$y not found\n";
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
            
            for $d (1..31) {
               $d = sprintf("%02d", $d);
               if ((!-d "/mnt/s3/$b/recordings/$domain/archive/$y/$m/$d")) {
                  warn "/mnt/s3/$b/recordings/$domain/archive/$y/$m/$d not found\n";
                  next;
               }
               
               for $filename (glob "/mnt/s3/$b/recordings/$domain/archive/$y/$m/$d/*") {
                  next unless $filename =~ /\.(?:wav|mp3)/i;
                  print "/mnt/s3/$b/recordings/$domain/archive/$y/$m/$d/$filename\n";
               }
            }
         }
      }
   }   
}



