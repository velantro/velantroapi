<?php
    require 'aws/aws-autoloader.php';
    use Aws\S3\S3Client;
    use Aws\Credentials\Credentials;
    
    $content = file_get_contents("/etc/aws");

    foreach (explode("\n", $content) as $line) {
        if (!$line)
                continue;
        list($s, $e) = explode('=', $line);
        if (!($s && $e))
                continue;

        $server_config["$s"] = $e;
    }

    $credentials = new Aws\Credentials\Credentials($server_config['aws_access_key_id'], $server_config['aws_secret_access_key']);

    $s3 = new Aws\S3\S3Client([
        'version'     => 'latest',
        'region'      => $server_config['region'],
        'credentials' => $credentials
    ]);
    
    $result = $s3->listBuckets();
    
    print_r($result);
?>