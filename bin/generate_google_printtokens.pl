$output = `gcloud --format=text projects list`;

for $row (split /\n/, $output) {
   if ($row =~ /projectId:\s+(.+)$/) {
      $agent = $1;
      warn "Start generate token for $agent: ";
      
      $token = `gcloud iam service-accounts keys create /tmp/$agent.json --iam-account smalltalkapi2\@$agent.iam.gserviceaccount.com`;
      print "$token !\n";
   }
   
}