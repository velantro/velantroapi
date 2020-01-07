use JSON;
$basedir = "/var/www/google";
$gcloud_bin = "/var/www/google-cloud-sdk/bin/gcloud";

for $dir (glob("$basedir/*")) {
    warn $dir;
    $ac = substr $dir, length($basedir)+1;
    push @accounts, $ac;
}

for $ac (@accounts) {
    warn "list agents for account $ac!\n";
    $json = `CLOUDSDK_CONFIG=$basedir/$ac  $gcloud_bin  --format=json projects list`;
    $hash = decode_json($json);
    
    for $ag (@$hash) {
        warn "agent: " . $ag->{projectId} . "\n";
        warn "generate print token for $ac - " . $ag->{projectId} . "\n";
        &generate_print_token($ac, $ag->{projectId});
    }
}



sub generate_print_token {
    $account = shift;
    $agent = shift;
    if (-e "$basedir/$account/$agent.conf") {
        warn "$basedir/$account/$agent.conf alreay generated!!\n";
        return;
    }
    
    $user = "smsapi";
    system("CLOUDSDK_CONFIG=$basedir/$account  $gcloud_bin config set project $agent");
    
    system("CLOUDSDK_CONFIG=$basedir/$account  $gcloud_bin  iam service-accounts create  $user");
    
    system("CLOUDSDK_CONFIG=$basedir/$account  $gcloud_bin projects add-iam-policy-binding  $agent  --member \"serviceAccount:$user\@$agent.iam.gserviceaccount.com\" --role \"roles/owner\"");
    
    system("CLOUDSDK_CONFIG=$basedir/$account  $gcloud_bin iam service-accounts keys create /tmp/$agent.json --iam-account $user\@$agent.iam.gserviceaccount.com");
    
    system("export GOOGLE_APPLICATION_CREDENTIALS=/tmp/$agent.json; CLOUDSDK_CONFIG=$basedir/$account  $gcloud_bin  auth application-default print-access-token > $basedir/$account/$agent.conf");
    
    system("cat $basedir/$account/$agent.conf");

}
