<?php
require 'aws/aws-autoloader.php';
require 'aws/AwsPolly.php';

$content = file_get_contents("/var/www/.aws/config");

$x = 0;
foreach (explode("\n", $content) as $line) {
	if (!$line)
		continue;
	list($s, $e) = explode(' = ', $line);
	if (!($s && $e)) 
		continue;
		
	$config["$s"] = $e;
}

$content = file_get_contents("/var/www/.aws/credentials");

$x = 0;
foreach (explode("\n", $content) as $line) {
	if (!$line)
		continue;
	list($s, $e) = explode(' = ', $line);
	if (!($s && $e)) 
		continue;
		
	$config["$s"] = $e;
}


print_r($config);
$polly = new AwsPolly(
    $config['aws_access_key_id'], 
    $config['aws_access_key_key'], 
    $config['region']
);

$param = [
    'language' => 'en-US',
    'voice' => 'Justin',
    'output_path' => '/tmp'
]

$file = $polly->textToVoice(
    'Hello World',
    $param
);

echo $file;



?>
