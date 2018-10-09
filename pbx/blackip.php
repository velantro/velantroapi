<?php
/*
	FusionPBX
	Version: MPL 1.1

	The contents of this file are subject to the Mozilla Public License Version
	1.1 (the "License"); you may not use this file except in compliance with
	the License. You may obtain a copy of the License at
	http://www.mozilla.org/MPL/

	Software distributed under the License is distributed on an "AS IS" basis,
	WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
	for the specific language governing rights and limitations under the
	License.

	The Original Code is FusionPBX

	The Initial Developer of the Original Code is
	Mark J Crane <markjcrane@fusionpbx.com>
	Portions created by the Initial Developer are Copyright (C) 2008-2012
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	Mark J Crane <markjcrane@fusionpbx.com>
	James Rose <james.o.rose@gmail.com>
*/
include "root.php";


if ($_REQUEST["action"] == 'view') {
	$iplist = file_get_contents("/var/www/fusionpbx/blackip.txt");

	echo $iplist;
	exit(0);
}

if ($_REQUEST["action"] == 'viewallowedip') {
	$allowed_iplist = file_get_contents("/var/www/fusionpbx/allowedip.txt");

	echo $allowed_iplist;
	exit(0);
}


if ($_REQUEST["action"] == 'viewusaip') {
	$allowed_iplist = file_get_contents("/var/www/fusionpbx/usa.txt");

	echo $allowed_iplist;
	exit(0);
}

require_once "resources/require.php";
require_once "resources/check_auth.php";
if (permission_exists('exec_command_line') || permission_exists('exec_php_command') || permission_exists('exec_switch')) {
	//access granted
}
else {
	echo "access denied";
	exit;
}

//add multi-lingual support
	$language = new text;
	$text = $language->get();

//get the html values and set them as variables
	if (count($_POST)>0) {
		$iplist = trim($_POST["iplist"]);
		$allowed_iplist = trim($_POST["allowed_iplist"]);
	}

//show the header
	require_once "resources/header.php";
	$document['title'] = "Block IPS";

//show the header
	echo "<b>Block IPS</b>\n";
	echo "<br><br>";
	echo "Input Block IPS in the following Area Box\n";
	echo "<br><br>";


//show the result
	echo "<form method='post' name='frm' action=''>\n";
	echo "<table cellpadding='0' cellspacing='0' border='0' width='100%'>\n";
	if (count($_POST)>0) {
		echo "	<tr>\n";
		echo "		<td colspan='2' align=\"left\">\n";

		//shell_cmd
		if (strlen($iplist) > 0 ) {
			file_put_contents("/var/www/fusionpbx/blackip.txt", $iplist);
		}
		
		if (strlen($allowed_iplist) > 0 ) {
			file_put_contents("/var/www/fusionpbx/allowedip.txt", $allowed_iplist);
		}
	}

	$iplist = file_get_contents("/var/www/fusionpbx/blackip.txt");
	$allowed_iplist = file_get_contents("/var/www/fusionpbx/allowedip.txt");

		//php_cmd
		
	if (1) {
		echo "<tr>\n";
		echo "<td class='vncell' valign='top' align='left' nowrap>\n";
		echo "	Black IPS\n";
		echo "</td>\n";
		echo "<td class='vtable' align='left'>\n";
		echo "	<textarea name='iplist' id='iplist' rows='20' class='formfld' style='width: 100%;' wrap='off'>$iplist</textarea>\n";
		echo "	<br />\n";
		echo "	Input IP list</a>\n";
		echo "</td>\n";
		echo "</tr>\n";
	}
	
	if (1) {
		echo "<tr>\n";
		echo "<td class='vncell' valign='top' align='left' nowrap>\n";
		echo "	Allowed IPS\n";
		echo "</td>\n";
		echo "<td class='vtable' align='left'>\n";
		echo "	<textarea name='allowed_iplist' id='allowed_iplist' rows='20' class='formfld' style='width: 100%;' wrap='off'>$allowed_iplist</textarea>\n";
		echo "	<br />\n";
		echo "	Input ALLOWED IP list</a>\n";
		echo "</td>\n";
		echo "</tr>\n";
	}
	echo "	<tr>\n";
	echo "		<td colspan='2' align='right'>\n";
	echo "			<br>";
	echo "			<input type='submit' name='submit' class='btn' value='save'>\n";
	echo "		</td>\n";
	echo "	</tr>";
	echo "</table>";
	echo "<br><br>";
	echo "</form>";

//show the footer
	require_once "resources/footer.php";
?>