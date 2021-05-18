use File::Copy;
$w =  shift;
if ($w == 1) {
   @base_dir = ('var/lib/freeswitch');
} elsif ($w == 2) {
   @base_dir = ('usr/local/freeswitch');
} else {
   @base_dir = ('var/lib/freeswitch', 'usr/local/freeswitch');
}

for $b (@base_dir) {
   while (</mnt/s3/$b/recordings/*>) {
      #print $_, "\n";
      ($domain) = $_ =~ m{recordings/(.+)$};
      if (not -d "/mnt/s3/$b/recordings/$domain/archive/2021") {
         print "$domain: " . "/mnt/s3/$b/recordings/$domain/archive/2021 not found!\n"; 
      }      
   }   
}



