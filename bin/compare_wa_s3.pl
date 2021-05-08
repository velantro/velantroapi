@base_dir = ('var/lib/freeswitch', 'usr/local/freeswitch');
@months = qw/Apr  Aug  Dec  Feb  Jan  Jul  Jun  Mar  May  Nov  Oct  Sep/;

for $b (@base_dir) {
   while (</mnt/s3/$b/recordings/*>) {
      #print $_, "\n";
      ($d) = $_ =~ m{recordings/(.+)$};
      print $d, "\n";
   }   
}
