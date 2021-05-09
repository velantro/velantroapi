@base_dir = ('var/lib/freeswitch', 'usr/local/freeswitch');

for $b (@base_dir) {
   while (</mnt/s3/$b/recordings/*>) {
      #print $_, "\n";
      ($domain) = $_ =~ m{recordings/(.+)$};
      print $domain, "...\n";
      $cmd = "find $_ -name \".wav\"";
      print "cmd: $cmd\n";
      $output = `$cmd`;
      for $rec (split /\n/, $output) {
         chomp $rec;
         ($p) = $rec =~ m{/mnt/s3/(.+)};
         if (-e "/mnt/wasabi/$p") {
            print "unlink /mnt/s3/$p\n";
         }         
      }     
   }   
}



