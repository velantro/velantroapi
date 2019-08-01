<?php
require 'aws/aws-autoloader.php';

require 'aws/AwsPolly.php';

$text = $argv[1];
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


#print_r($config);
$polly = new TBETool\AwsPolly(
    $config['aws_access_key_id'], 
    $config['aws_secret_access_key'], 
    $config['region']
);

$param = array(
    'language' => 'en-US',
    'voice' => 'Joanna',
    'output_path' => '/tmp'
);

$filename = $polly->textToVoice(
    $text,
    $param
);

echo $filename;

?>
