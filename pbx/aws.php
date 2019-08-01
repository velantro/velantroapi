<?php
require 'aws/aws-autoloader.php';

use Aws\Route53\Route53Client;

$client = Route53Client::factory(array(
	'region' => 'us-west-2',
	'version' => 'latest'
));

$flagmannet_hostzone_id = "/hostedzone/ZAGXT74B44TLV";

$result = $client->listResourceRecordSets(array(
    // HostedZoneId is required
    'HostedZoneId' => $flagmannet_hostzone_id
));
#print_r($result['ResourceRecordSets']);
foreach ($result['ResourceRecordSets'] as $tmp) {
   #print_r($domain);
   if ($tmp['Type'] != 'A') {
	  continue;
   }
   $domain_name = substr($tmp['Name'], 0, strlen($tmp['Name'])-1);
   $domains[$domain_name] = $tmp['ResourceRecords'][0]['Value'];
}

print_r($domains);

?>
