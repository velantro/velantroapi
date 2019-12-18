$output = `gcloud --format=text projects list`;

for $row (split /\n/, $output) {
   if ($row =~ /projectId:\s+(.+)$/) {
      $agent = $1;
      warn "Start generate token for $agent: \n";
      
      $token = `gcloud iam service-accounts keys create /tmp/$agent.json --iam-account smalltalkapi2\@$agent.iam.gserviceaccount.com`;
      $token = `export GOOGLE_APPLICATION_CREDENTIALS=/tmp/$agent.json ; gcloud auth application-default print-access-token`;
      print $token, "\n";
   }
   
}