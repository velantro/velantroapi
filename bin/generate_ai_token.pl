$account = shift;
$agent = shift;

$user = "smsapi";
system("CLOUDSDK_CONFIG=/var/www/google/$account  /var/www/google-cloud-sdk/bin/gcloud config set project $agent");

system("CLOUDSDK_CONFIG=/var/www/google/$account  /var/www/google-cloud-sdk/bin/gcloud  iam service-accounts create  $user");

system("CLOUDSDK_CONFIG=/var/www/google/$account  /var/www/google-cloud-sdk/bin/gcloud projects add-iam-policy-binding  $agent  --member \"serviceAccount:$user\@$agent.iam.gserviceaccount.com\" --role \"roles/owner\"");

system("CLOUDSDK_CONFIG=/var/www/google/$account  /var/www/google-cloud-sdk/bin/gcloud iam service-accounts keys create /tmp/$agent.json --iam-account $user\@$agent.iam.gserviceaccount.com");

system("export GOOGLE_APPLICATION_CREDENTIALS=/tmp/$agent.json; CLOUDSDK_CONFIG=/var/www/google/$account  /var/www/google-cloud-sdk/bin/gcloud  auth application-default print-access-token > /var/www/google/$account/$agent.conf");

system("cat /var/www/google/$account/$agent.conf");


