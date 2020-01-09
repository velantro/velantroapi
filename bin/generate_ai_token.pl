use JSON;
$action = shift;
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
        if ($action eq 'check') {
            &test_print_token($ac, $ag->{projectId});
        } else {        
            &generate_print_token($ac, $ag->{projectId});
        }
    }
}

sub test_print_token {
    $account = shift;
    $agent = shift;
    if (!-e "$basedir/$account/$agent.conf") {
        print "$account|$agent : FAIL: " . "$basedir/$account/$agent.conf not existed!!\n";
        return;
    }
    $token = `cat $basedir/$account/$agent.conf`; chomp $token;
    $uuid = `uuid`;chomp $uuid;
    $json = `curl -H "Content-Type: application/json; charset=utf-8"  -H "Authorization: Bearer $token"  -d "{\"queryInput\":{\"text\":{\"text\":\"hi\",\"languageCode\":\"en\"}}}" "https://dialogflow.googleapis.com/v2/projects/$agent/agent/sessions/$uuid:detectIntent`;
    $hash = decode_json($json);

    if ($hash && !$hash->{error}) {
        print "$account|$agent : OK!\n";
    } else {
        print "$account|$agent : FAIL!\n"
    }
}

sub generate_print_token {
    $account = shift;
    $agent = shift;
    warn "generate print token for $ac - " . $ag->{projectId} . "\n";

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
