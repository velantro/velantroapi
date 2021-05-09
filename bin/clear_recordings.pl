@base_dir = ('var/lib/freeswitch', 'usr/local/freeswitch');

for $b (@base_dir) {
   while (</mnt/s3/$b/recordings/*>) {
      #print $_, "\n";
      ($domain) = $_ =~ m{recordings/(.+)$};
      print $domain, "...\n";
      $cmd = "find $_/archive -name \".wav\"";
      print "$cmd > /var/log/recordings_$domain.list &\n";      
   }   
}



