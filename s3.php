<?php
    require '/var/www/aws/aws-autoloader.php';
    use Aws\S3\S3Client;
    use Aws\Credentials\Credentials;
    use Aws\Exception\AwsException;

    $debug = true;
    $content = file_get_contents("/etc/aws");

    foreach (explode("\n", $content) as $line) {
        if (!$line)
                continue;
        list($s, $e) = explode('=', $line);
        if (!($s && $e))
                continue;

        $server_config["$s"] = $e;
    }

    $recording_bucket = $server_config['bucket'];
    if (!$recording_bucket) {
        $recording_bucket = 'backuprecordings';
    }
    $credentials = new Aws\Credentials\Credentials($server_config['aws_access_key_id'], $server_config['aws_secret_access_key']);

    $s3 = new Aws\S3\S3Client(array(
        'version'     => 'latest',
        'region'      => $server_config['region'],
        'credentials' => $credentials
    ));
    
    
    $buckets  = $s3->listBuckets();
    foreach ($buckets['Buckets'] as $bucket) {
        echo "Bucket: " . $bucket['Name'] . "\n";
        if ($bucket['Name'] == $recording_bucket) {
            $is_bucketed_created = 1;
            break;
        }
    }
    
    if (!$is_bucketed_created) {
        $status = createbucket($recording_bucket);
        if (!$status) {
            echo "fail to create bucket: $recording_bucket!\n";
            exit;
        }
    }
    
    $new_name = 'Composer.phar';
    $file = "/var/www/composer.phar";
    $status = uploadrecording($recording_bucket, $new_name, $file);
    if (!$status) {
        echo "Fail to upload $file to $recording_bucket/$new_name!\n";
        exit;
    }
    if ($debug) {
       
    }
    
    function createbucket($bucket) {
        global $s3, $e;
        try {
             $result = $s3->createBucket([
                'Bucket' => $bucket,
            ]);
         }
         catch (AwsException $e) {
            echo $e->getMessage();
            echo "\n";
            return false;
        }
    
        if ($result['@metadata']['statusCode'] == 200) {
            return true;
        } else {
            return false;
        }       
    }
    
    function uploadrecording($bucket, $key, $file_path) {
        global $s3, $e, $debug;

        try {
            $result = $s3->putObject([
                'Bucket' => $bucket,
                'Key' => $key,
                'SourceFile' => $file_path,
            ]);
        } catch (S3Exception $e) {
                echo $e->getMessage() . "\n";
        }
        if ($result['@metadata']['statusCode'] == 200) {
            if ($debug) {
                echo "Successfully upload $file_path to $bucket/$key: ";
                echo $result['ObjectURL'] . "\n";
            }
            return true;
        } else {
            return false;
        }       
    }
?>