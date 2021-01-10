<?php
$descriptorspec = array(
   0 => array("pipe", "r"), 
   1 => array("pipe", "w"),
   2 => array("file", "/tmp/bc", "a")
);

$cwd = '/tmp';
#$env = array('some_option' => 'aeiou');
/*
$process = proc_open('php', $descriptorspec, $pipes, $cwd, $env);

if (is_resource($process)) {
    

    fwrite($pipes[0], '<?php print_r($_ENV); ?>');
    fclose($pipes[0]);

    echo stream_get_contents($pipes[1]);
    fclose($pipes[1]);
    

    $return_value = proc_close($process);

    echo "command returned $return_value\n";
}*/

$process = proc_open('CLOUDSDK_CONFIG=/var/www/zhongxiang721 /var/www/google-cloud-sdk/bin/gcloud auth login', $descriptorspec, $pipes, $cwd);

if (is_resource($process)) {
    

    #fwrite($pipes[0], '');
    fclose($pipes[0]);

    echo stream_get_contents($pipes[1]);
    fclose($pipes[1]);
    

    $return_value = proc_close($process);

    echo "command returned $return_value\n";
}
?>
