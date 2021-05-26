<?php
if (defined('STDIN')) {
	$document_root = str_replace("\\", "/", $_SERVER["PHP_SELF"]);
	preg_match("/^(.*)\/secure\/.*$/", $document_root, $matches);
	$document_root = $matches[1];
	set_include_path($document_root);
	$_SERVER["DOCUMENT_ROOT"] = $document_root;
}

//includes
if (!defined('STDIN')) { include "root.php"; }
require_once "resources/require.php";

$ivr_menu_uuid = $argv[1];
$keypress = $argv[2];
$src = $argv[3];
$dst = $argv[4];
send_sms($ivr_menu_uuid, $keypress, $src, $dst);

function send_sms($ivr_menu_uuid,$keypress,$f, $t) {
	global $db, $debug;
	if ($debug) {
		error_log("$f $t $r \n");
	}
	
	
	
	$sql = "SELECT ivr_menu_option_description FROM  ";
	$sql = $sql . " v_ivr_menu_options ";
	$sql = $sql . "WHERE ivr_menu_uuid = '$ivr_menu_uuid' and ";
	$sql = $sql . "ivr_menu_option_digits = '$keypress'";
	
	$prep_statement = $db->prepare(check_sql($sql));
	$prep_statement->execute();
	$result = $prep_statement->fetchAll(PDO::FETCH_NAMED);
	if (count($result) == 0) {
		error_log("Cannot find a the ivr option: " . print_r($result,true));
		#die("Invalid Destination");
	}
	foreach ($result as &$row) {
		$r = $row["ivr_menu_option_description"];
		break;
	}
/*	
	$sql = "SELECT carrier FROM  ";
	$sql = $sql . " v_sms_destinations ";
	$sql = $sql . "WHERE destination = '$f' and ";
	$sql = $sql . "enabled = 'true'";
	
	$prep_statement = $db->prepare(check_sql($sql));
	$prep_statement->execute();
	$result = $prep_statement->fetchAll(PDO::FETCH_NAMED);
	if (count($result) == 0) {
		error_log("Cannot find a destination: " . print_r($result,true));
		#die("Invalid Destination");
	}
	foreach ($result as &$row) {
		$carrier = $row["carrier"];
		break;
	}
*/	
	$carrier = $carrier ? $carrier : 'velantro';
	
	$sql = "SELECT default_setting_value FROM v_default_settings ";
	$sql = $sql .  "where default_setting_category = 'sms' and default_setting_subcategory = '" .$carrier. "_access_key' and default_setting_enabled = 'true'";
	$prep_statement = $db->prepare(check_sql($sql));
	$prep_statement->execute();
	$result = $prep_statement->fetchAll(PDO::FETCH_NAMED);
	
	foreach ($result as &$row) {
		$access_key = $row["default_setting_value"];
		break;
	}

	$sql = "SELECT default_setting_value FROM v_default_settings ";
	$sql = $sql .  "where default_setting_category = 'sms' and default_setting_subcategory = '" .$carrier. "_secret_key' and default_setting_enabled = 'true'";
	$prep_statement = $db->prepare(check_sql($sql));
	$prep_statement->execute();
	$result = $prep_statement->fetchAll(PDO::FETCH_NAMED);
	
	foreach ($result as &$row) {
		$secret_key = $row["default_setting_value"];
		break;
	}

	$sql = "SELECT default_setting_value FROM v_default_settings ";
	$sql = $sql .  "where default_setting_category = 'sms' and default_setting_subcategory = '" .$carrier. "_api_host' and default_setting_enabled = 'true'";
	$prep_statement = $db->prepare(check_sql($sql));
	$prep_statement->execute();
	$result = $prep_statement->fetchAll(PDO::FETCH_NAMED);
	
	foreach ($result as &$row) {
		$api_host = $row["default_setting_value"];
		break;
	}
	if (strlen($f) < 11) {
		$f = "1$f";
	}
	$body = $r;
	#$body = preg_replace('/\'/',"'\"'\"", $r);
	#$cmd = "curl  -k -X POST " . $api_url . " -d 'key=" . $access_key . "&senderid=" . $f . "&type=text&contacts=" . $t . "&msg=" . $body . "'";
	
	#$output = shell_exec($cmd);
	
	#$cache = new cache;
	#$val = $cache->get("access_key_$f");
	if (!$val || preg_match('/\W/', $val)) {
		$api_url = "https://$api_host/app/getkey/$f";
		$ch = curl_init();
		curl_setopt($ch, CURLOPT_URL, $api_url);
		curl_setopt($ch, CURLOPT_HEADER,0);

	
		curl_setopt($ch, CURLOPT_RETURNTRANSFER,1);
		curl_setopt($ch, CURLOPT_FOLLOWLOCATION,1);
		curl_setopt($ch, CURLOPT_SSL_VERIFYPEER,false);
		curl_setopt($ch, CURLOPT_SSL_VERIFYHOST,false);
		$output = curl_exec($ch);
		curl_close($ch);
		
		if ($debug) {
			error_log('Key Req: ' .  $api_url . "\n" . "Res: $output\n");		
		}
		
		$key = preg_replace('/\W/', '', $output);
		if ($key) {
	#		$cache->set("access_key_$f", $key);
			$access_key = $key;
		}
		unset($ch);
	} else {
		$access_key = $val;
	}
	
	$ch = curl_init();
	$cmd = "key=$access_key&senderid=$f&type=text&contacts=$t&msg=$body";

	curl_setopt($ch, CURLOPT_URL, "https://$api_host/app/smsapipost");
	curl_setopt($ch, CURLOPT_HEADER,0);
	curl_setopt($ch, CURLOPT_POST, 1);
	curl_setopt($ch, CURLOPT_POSTFIELDS, $cmd);

	curl_setopt($ch, CURLOPT_RETURNTRANSFER,1);
	curl_setopt($ch, CURLOPT_FOLLOWLOCATION,1);
	curl_setopt($ch, CURLOPT_SSL_VERIFYPEER,false);
	curl_setopt($ch, CURLOPT_SSL_VERIFYHOST,false);
	$output = curl_exec($ch);
	curl_close($ch);
	
	if ($debug) {
		error_log('SendSMS Req: ' .  $cmd . "\n" . "Res: $output\n");
	}
}


?>