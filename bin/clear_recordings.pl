use File::Copy;
$w =  shift;
if ($w == 1) {
   @base_dir = ('var/lib/freeswitch');
} elsif ($w == 2) {
   @base_dir = ('usr/local/freeswitch');
} else {
   @base_dir = ('var/lib/freeswitch', 'usr/local/freeswitch');
}

$select_domain = shift;
for $b (@base_dir) {
   while (</mnt/s3/$b/recordings/*>) {
      #print $_, "\n";
      ($domain) = $_ =~ m{recordings/(.+)$};
      #print $d, "\n";
      
      if ($select_domain && $select_domain ne $domain) {
         next;
      }      
      
      
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
                  next unless $filename =~ m{/mnt/s3/(.+)\.(wav|mp3)}i;
                  $wa_file = "/mnt/wasabi/$1.$2";
                  if (!-e $wa_file) {
                     print "copy $filename to $wa_file!\n";
                     if (not -d "/mnt/wasabi/$b/recordings/$domain/archive/$y/$m/$d" ) {
                        print "mdir \"/mnt/wasabi/$b/recordings/$domain/archive/$y/$m/$d\"\n";
                        mkdir "/mnt/wasabi/$b/recordings/$domain/archive/$y/$m/$d";
                     }                     
                     copy($filename, $wa_file) or next;                                         
                  }
                  print "unlink $filename!\n";
                  unlink $filename;                  
               }
            }
         }
      }
   }   
}



