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


#print_r($config);
$polly = new TBETool\AwsPolly(
    $config['aws_access_key_id'], 
    $config['aws_secret_access_key'], 
    $config['region']
);

$param = [
    'language' => 'en-US',
    'voice' => 'Joanna',
    'output_path' => '/tmp'
];

$filename = $polly->textToVoice(
    'Set absolute path of the directory where to save the output. You dont need to provide a file name as it will be auto generated.',
    $param
);

if(file_exists($filename)) {
    header('Content-Type: audio/mpeg');
    header('Content-Disposition: filename="test.mp3"');
    header('Content-length: '.filesize($filename));
    header('Cache-Control: no-cache');
    header("Content-Transfer-Encoding: chunked"); 

    readfile($filename);
	unlink($filename);
} else {
    header("HTTP/1.0 404 Not Found");
}

?>
