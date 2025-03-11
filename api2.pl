#!/usr/bin/perl

use CGI::Simple;
$CGI::Simple::DISABLE_UPLOADS = 0;
$CGI::Simple::POST_MAX = 1_000_000_000;

use HTTP::Request::Common;
use LWP::UserAgent;
use HTTP::Cookies;
use HTTP::Date;
use JSON;
use YAML;
use DBI;
use MIME::Base64;
use LWP::Simple;
use URI::Escape;
$CGI::Simple::POST_MAX = 10_048_576;

my ($adb, $ahost, $auser, $apass) = ('fusionpbx', '127.0.0.1', 'fusionpbx', 'fusionpbx');

my %month = ('01' => 'Jan', '02'=> 'Feb', '03'=>'Mar', '04'=>'Apr','05'=>'May', '06'=>'Jun','07'=>'Jul','08'=>'Aug',
						 '09' => 'Sep', '10'=> 'Oct', '11'=>'Nov', '12'=>'Dec');
my $recordings_dir = '/usr/local/freeswitch/recordings';

my $cgi   = CGI::Simple->new();
#my @names = $cgi->param;

my $remote_ip = $cgi->remote_addr();

my %query = '';
=pod
for (@names) {
	my $v = $cgi->param($_);
    $query{$_} = $v;
	#warn "$_ : $v";
}
=cut

if ($cgi->request_method eq 'GET') {
	$query_string = uri_unescape($cgi->query_string());
	for (split /&|&&/, $query_string) {
		#warn $_;
		($var, $val) = split '=', $_, 2;
		$query{$var} = $val;
		
		#warn "$var ==> $val";
	}
} else {
	for my $key ($cgi->url_param) {
		$query{$key} = $cgi->url_param($key);
		warn "POST $key ==> "  . $cgi->url_param($key);
	}
	for my $key ($cgi->param) {
		$query{$key} = $cgi->param($key);
		#warn "POST $key ==> "  . $cgi->param($key);
	}
}
if ($query{msgid}) {
	$query{action} = 'savesms';
}

my $ua  = LWP::UserAgent->new('agent' => "Mozilla/5.0 (Windows; U; Windows NT 5.1; zh-CN; rv:1.9.2.13) Gecko/20101203 Firefox/3.6.13 GTB7.1");
my $jar = HTTP::Cookies->new(
    file => "/tmp/cookie.txt",
    autosave => 1,
);

my ($api_login, $api_pass);

my $txt = `cat /etc/vconnect.conf`;
my %config = ();
for (split /\n/, $txt) {
	my ($key, $val)	= split /=/, $_, 2;
	
	if ($key) {
		$config{$key} = $val;
		#warn "$key=$val\n";
	}
}

$adb = $config{dbname} if $config{dbname};
$ahost = $config{dbhost} if $config{dbhost};
$auser = $config{dbuser} if $config{dbuser};
$apass = $config{dbpass} if $config{dbpass};
$max_incoming_event_duration = $config{max_incoming_event_duration} || 30;

my $dbh = '';
if ($config{dbtype} eq 'sqlite') {
	$dbh = DBI->connect("dbi:SQLite:dbname=/var/www/fusionpbx/secure/fusionpbx.db","","");
} elsif($config{dbtype} eq 'pg') {
	$dbh = DBI->connect("DBI:Pg:database=$adb;host=$ahost", "$auser", "$apass", {RaiseError => 0, AutoCommit => 1});
} else {
	$dbh = DBI->connect("DBI:mysql:database=$adb;host=$ahost", "$auser", "$apass", {RaiseError => 0, AutoCommit => 1});
	
}

if (!$dbh) {
	print j({error => '1', 'message' => 'internal error: fail to login db', 'actionid' => $query{actionid}});
	exit 0;
}
warn "login db: OK!\n";

my $txt = `cat /etc/api.conf`; #chomp $txt;
#my ($username, $password) = split ':', $txt, 2;
my %config = ();
for (split /\n/, $txt) {
	my ($key, $val)	= split /:/, $_, 2;
	
	if ($key) {
		$login{$key} = $val;
		#warn "$key=$val\n";
	}
}
#warn "$username==$password";
if ($query{action} eq 'login') {
	my $error = 0;
	my $msg = 'ok';
	my $old_session_uuid  = $cgi->cookie('session_uuid');
	if ($old_session_uuid) {
		#remove old session in db if relogin
		$dbh->prepare("delete from v_api_session where  session_uuid='$old_session_uuid'")->execute();
	}
	$domain = $cgi->server_name();
	($rd) = $domain =~ /(\w+)\./;
	#print $query{username}, ":" , $query{password}, ":", $login{$query{username}};
	$sth = $dbh->prepare("select domain_setting_value from v_domain_settings left join v_domains on v_domain_settings.domain_uuid=v_domains.domain_uuid where domain_setting_subcategory='c2ckey' and domain_name='$domain'");
	$sth->execute;
	$row = $sth->fetchrow_hashref;
	$saved_pass = $row->{domain_setting_value};
	
	
	if (($login{$query{username}} && $login{$query{username}} eq $query{password}) || ($rd eq $query{username} && $saved_pass eq $query{password})) {	

		my $uuid = _uuid();
		my $cookie1 = $cgi->cookie( -name  => 'session_uuid',
						-value => $uuid,
						-expires => '+24h'
					  );
		
		$dbh->prepare("insert into v_api_session (session_uuid) values('$uuid')")->execute();
		print $cgi->header(-cookie => $cookie1);
	} else {
		$error = 1;
		$msg = 'Auth Fail';
		print $cgi->header(-status => 403);
	}
	
	print j({error => $error, 'message' => $msg, 'actionid' => $query{actionid}});
	exit 0;

}
my $session_uuid  = $cgi->cookie('session_uuid');

my $login_ok;
if ($session_uuid) {
	my $sql = "select session_uuid from v_api_session where session_uuid='$session_uuid' and now() < insert_time + interval '24 H'";
	warn $sql;
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	my $row = $sth->fetchrow_hashref;
	
	if ($row) {
		$login_ok = 1;
	}
	
}

if (!$login_ok) {
	print $cgi->header(-status => 403,-type => 'application/json',
					   -access_control_allow_origin => '*',
						-access_control_allow_headers => 'content-type,X-Requested-With',
						-access_control_allow_methods => 'GET,POST,OPTIONS',
						-access_control_allow_credentials => 'true');

	print j({error => 1, 'message' => "Not Login", 'actionid' => $query{actionid}});
	exit 0;
}


if ($query{action} eq 'getincomingevent') {
	print $cgi->header(-type  =>  'text/event-stream;charset=UTF-8', '-cache-control' => 'NO-CACHE', );
} else {
	print $cgi->header(
						-type => 'application/json',
					   -access_control_allow_origin => '*',
						-access_control_allow_headers => 'content-type,X-Requested-With',
						-access_control_allow_methods => 'GET,POST,OPTIONS',
						-access_control_allow_credentials => 'true');
	
}

$ua->cookie_jar($jar);

=pod
my $signurl = "http://$HOSTNAME/core/user_settings/user_dashboard.php?username=vconnect&&password=vconnect123--";
if ($query{action} ne 'getcallhistory') {
	my $res = $ua->request(GET $signurl);
	if ($res->content !~ /User Information/) {
		print j({error => '1', 'message' => 'internal error: fail to login pbx', 'actionid' => $query{actionid}});
		warn $res->content;
		exit 0;
	}
	warn "login pbx: OK!\n";
}
=cut





if ($query{action} eq 'addcallback') {
	add_callback();
} elsif ($query{action} eq 'sendcallback') {
	send_callback();
} elsif ($query{action} eq 'getlivechannels') {
	get_livechannels();
} elsif ($query{action} eq 'startmoh') {
	start_moh();
} elsif ($query{action} eq 'stopmoh') {
	stop_moh();
} elsif ($query{action} eq 'hangup') {
	hangup();
} elsif ($query{action} eq 'route53') {
	do_route53();
} elsif ($query{action} eq 'getcallbackstate') {
	get_callbackstate();
} elsif ($query{action} eq 'gettenant') {
	get_tenant();
} elsif ($query{action} eq 'gettenanthtml') {
	get_tenant_html();
} elsif ($query{action} eq 'getincoming') {
	get_incoming();
} elsif ($query{action} eq 'getincomingevent') {
	get_incoming_event();
} elsif ($query{action} eq 'addautocallback') {
	add_autocallback();
} elsif ($query{action} eq 'autocallstate'){
	get_autocallstate();
} elsif ($query{action} eq 'autocallhangup'){
	do_autocallhangup();
} elsif ($query{action} eq 'transfer'){
	do_transfer();
} elsif ($query{action} eq 'transferincoming'){
	$query{direction} = 'incoming';
	do_transfer();
} elsif ($query{action} eq 'uploadvoicemaildrop'){
	do_upload_voicemaildrop();
} elsif ($query{action} eq 'listvoicemaildrop'){
	do_list_voicemaildrop();
} elsif ($query{action} eq 'deletevoicemaildrop'){
	do_delete_voicemaildrop();
} elsif ($query{action} eq 'updatevoicemaildrop'){
	do_update_voicemaildrop();
} elsif ($query{action} eq 'sendvoicemaildrop'){
	do_send_voicemaildrop();
} elsif ($query{action} eq 'getvoicemaildrop'){
	do_get_voicemaildrop();
} elsif ($query{action} eq 'hold'){
	do_hold();
} elsif ($query{action} eq 'unhold'){
	do_unhold();
} elsif ($query{action} eq 'getcdrbydid' || $query{action} eq 'getcdr'){
	do_cdr();
} elsif ($query{action} eq 'getteledirectminutes'){
	do_teledirect();
} elsif ($query{action} eq 'checkextension'){
	do_checkextension();
}else {
     print j({error => '1', 'message' => 'undefined action', 'actionid' => $query{actionid}});
    exit 0;
}

sub j {
    return encode_json(shift);
}

sub add_callback {
	if (!$query{widgetid}) {		
		print j({error => '1', 'message' => 'ok: no widgetid define', 'actionid' => $query{actionid}});
		exit 0;
	}
	
	my $sql = "select user_context,extension,domain_uuid from v_extensions,vconnect_widget where v_extensions.extension_uuid=vconnect_widget.extension_uid and (widgetid='$query{widgetid}')" ;
	warn $sql;
	my $sth = $dbh->prepare($sql);	
	$sth->execute();	
	my $row = $sth->fetchrow_hashref;
	
	my $ext 	= $row->{extension};
	
	my $dest	= $query{dest};
	if (!$query{dest}) {		
		print j({error => '1', 'message' => 'error: no dest define', 'actionid' => $query{actionid}});
		exit 0;
	}
	
	my $uuid   = _uuid();
	#my $result = `fs_cli -x "originate {origination_caller_id_name=callback-$ext,origination_caller_id_number=8188886666,domain_name=$HOSTNAME,origination_uuid=$uuid}loopback/$ext/$HOSTNAME/XML $dest XML $HOSTNAME"`;
	if ($dest =~ /^\+(\d+)$/) {
		$dest = "011$1";
	}
	
	$dest	  =~ s/\D//g;

	if ($dest =~ /^\d{10}$/) {
		$dest = "1$dest";
	}
	
	my $callerid = $query{callerid} || '8188886666';

	my $result = `fs_cli -x "bgapi originate {execute_on_answer='lua callback.lua startmoh $uuid $query{widgetid}',ringback=local_stream://default,ignore_early_media=true,fromextension=$ext,origination_caller_id_name=callback-$ext,origination_caller_id_number=$callerid,outbound_caller_id_number=$callerid,outbound_caller_id_name=callback-$ext,domain_name=$HOSTNAME,origination_uuid=$uuid,sip_h_X-accountcode=6915654132}loopback/$ext/$HOSTNAME/XML $dest XML $HOSTNAME"`; #sofia/gateway/vconnect.velantro.net-newa2b/$dest $ext XML $HOSTNAME"`;
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid},callbackid => $uuid});	

	#originate {origination_caller_id_name=vconnect_callback,origination_caller_id_number=8188886666,domain_name=vconnect.velantro.net}loopback/8184885588/vconnect.velantro.net/XML 100031 XML vconnect.velantro.net
}

sub add_autocallback {
	if (!$query{widgetid}) {		
		print j({error => '1', 'message' => 'ok: no widgetid define', 'actionid' => $query{actionid}});
		exit 0;
	}
	
	my $sql = "select user_context,extension,domain_uuid from v_extensions,vconnect_widget where v_extensions.extension_uuid=vconnect_widget.extension_uid and (widgetid='$query{widgetid}')" ;
	warn $sql;
	my $sth = $dbh->prepare($sql);	
	$sth->execute();	
	my $row = $sth->fetchrow_hashref;
	
	my $ext 	= $row->{extension};
	
	my $dest	= $query{dest};
	if (!$query{dest}) {		
		print j({error => '1', 'message' => 'error: no dest define', 'actionid' => $query{actionid}});
		exit 0;
	}
	my $callerid = $query{callerid} || '8188886666';
	
	my $uuid   = _uuid();
	
	#my $result = `fs_cli -x "originate {origination_caller_id_name=callback-$ext,origination_caller_id_number=8188886666,domain_name=$HOSTNAME,origination_uuid=$uuid}loopback/$ext/$HOSTNAME/XML $dest XML $HOSTNAME"`;
	if ($dest =~ /^\+(\d+)$/) {
		$dest = "011$1";
	}
	
	my $forward_type = `fs_cli -x "db select/vconnect_dsttype/$ext"`;
	my $forward_dest = `fs_cli -x "db select/vconnect/$ext"`;
	
	if ($forward_dest =~ /^\+(\d+)$/) {
		$forward_dest = "011$1";
	}
	
	
	my $reg_txt = `fs_cli -x "show registrations"`;
	
	my $is_reg = 0;
	my $reg_domain = 'sipvconnect.velantro.net';
	for (split /\n/, $reg_txt) {
		if (index($_, "$ext,$reg_domain,") == 0) {
			$forward_dest = "777777$ext";
			last;
		}
	}
	
	$forward_dest =~ s/\D//g;
	my $is_widget_in_conference = 0;
	my $conf_list = `fs_cli -x "conference $ext list"`;
	for (split /\n/, $conf_list) {
		if (index($_, "loopback/$forward_dest-a") != -1) {
			$is_widget_in_conference = 1;
			last;
		}
	}
	my $result = `fs_cli -x "conference $ext kick non_moderator"`;
	
	if (!$is_widget_in_conference) {
		my $result = `fs_cli -x "originate {origination_caller_id_name=callback-$ext,origination_caller_id_number=$callerid,domain_name=$HOSTNAME,ignore_early_media=true,origination_uuid=$uuid,flags=endconf|moderator}loopback/$forward_dest/$HOSTNAME/XML conference$ext XML $HOSTNAME"`;
		sleep 2;
		
		my $call_list = `fs_cli -x "show calls"`;
		my $is_ext_answered = 0;
		for (split /\n/, $call_list) {
			if (index($_, "$uuid,") == 0) {
				$is_ext_answered = 1;
				last;
			}
		}
	
		if (!$is_ext_answered) {
			print j({error => '1', 'message' => "$forward_dest not answered", 'actionid' => $query{actionid}, 'uuid' => $uuid} );
			exit 0;
		}
	}
	
	
	$uuid = _uuid();
	$result = `fs_cli -x "bgapi originate {origination_caller_id_name=callback-$ext,origination_caller_id_number=$callerid;,domain_name=$HOSTNAME,origination_uuid=$uuid,autocallback_fromextension=$ext,is_lead=1}loopback/$dest/$HOSTNAME/XML conference$ext XML $HOSTNAME"`;
	
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}, 'callbackid' => $uuid});	

}

sub send_callback {	
	my $ext 	= $query{ext};
	my $domain  = $query{domain} || $HOSTNAME;
	$domain		= $cgi->server_name();
	
	
	my $auto_answer = $query{autoanswer}  ? "sip_h_Call-Info=<sip:$domain>;answer-after=0,sip_auto_answer=true" : "";
	my $alert_info  = $query{autoanswer}  ? "sip_h_Alert-Info='Ring Answer'" : '';
	my $dest	= $query{dest};
	my $template_file = 'firefox-c2c-popup.html';
	if (!$query{dest}) {
		if ($query{from} eq 'firefox') {
			template_print($template_file, {error => '1', 'message' => 'error: no dest define', 'actionid' => $query{actionid}});
		} else {
			print j({error => '1', 'message' => 'error: no dest define', 'actionid' => $query{actionid}});
		}
		exit 0;
	}
	
	my $uuid   = _uuid();
	#my $result = `fs_cli -x "originate {origination_caller_id_name=callback-$ext,origination_caller_id_number=8188886666,domain_name=$HOSTNAME,origination_uuid=$uuid}loopback/$ext/$HOSTNAME/XML $dest XML $HOSTNAME"`;
	$dest =~ s/^\+1//g;
	if ($dest =~ /^\+(\d+)$/) {
		$dest = "011$1";
	}
	
	my $realdest = $dest;
	$fs_cli = 'fs_cli';
	
	$dest =~ s/^1//g;
	$dest =~ s/\D//g;

	$realdest = "$dest" unless $dest =~ /^(?:\+|011)/;
	my $cid = get_outbound_callerid($domain, $ext) || $dest;
	warn "cid=$cid";
	
	$res = `fs_cli -rx "show registrations" | grep "$ext,$domain"`;
	chomp $res;
	if (length($res) < 1) {
		print j({error => '1', 'message' => "error: The extension $ext is not registered. Check the connection and try again. ", 'actionid' => $query{actionid}});
		return;
	}
	
	
	# bgapi originate {ignore_early_media=true,fromextension=188,origination_caller_id_name=8882115404,origination_caller_id_number=8882115404,effective_caller_id_number=8882115404,effective_caller_id_name=8882115404,domain_name=vip.velantro.net,origination_uuid=14061580998073}loopback/188/vip.velantro.net 8882115404 XML vip.velantro.net
	#my $result = `$fs_cli -x "bgapi originate {ringback=local_stream://default,ignore_early_media=true,absolute_codec_string=PCMA,fromextension=$ext,origination_caller_id_name=$dest,origination_caller_id_number=$dest,effective_caller_id_number=$cid,effective_caller_id_name=$cid,domain_name=$domain,outbound_caller_id_number=$cid,$alert_info,origination_uuid=$uuid,$auto_answer}loopback/$ext/$domain $realdest XML $domain"`;
	#my $result = `$fs_cli -x "bgapi originate {ringback=/var/www/api/usring.wav,ignore_early_media=true,absolute_codec_string=PCMA,fromextension=$ext,origination_caller_id_name=$dest,origination_caller_id_number=$dest,effective_caller_id_number=$dest,effective_caller_id_name=$dest,domain_name=$domain,outbound_caller_id_number=$dest,$alert_info,origination_uuid=$uuid,$auto_answer}user/$ext\@$domain &bridge([origination_caller_id_name=$cid,origination_caller_id_number=$cid,effective_caller_id_number=$cid,effective_caller_id_name=$cid,iscallback=$ext,outbound_caller_id_number=$cid,user_record=all,record_session=true,ringback=/var/www/api/usring.wav,ring_ready=true]loopback/$dest/$domain)"`;
	my ($y,$m,$d) = &get_today();
	
	my $execute_on_answer = "execute_on_answer='record_session /var/lib/freeswitch/recordings/$domain/archive/$y/$m/$d/$uuid.wav'";

	my $cmd = qq{$fs_cli -x "bgapi originate {ringback=/var/www/api/usring.wav,ignore_early_media=true,absolute_codec_string=PCMA,fromextension=$ext,origination_caller_id_name=$dest,origination_caller_id_number=$dest,domain_name=$domain,outbound_caller_id_number=$dest,$alert_info,origination_uuid=$uuid,$auto_answer,$execute_on_answer}user/$ext\@$domain &bridge([origination_caller_id_name=$cid,origination_caller_id_number=$cid,iscallback=$ext,outbound_caller_id_number=$cid,user_record=all,record_session=true,ringback=/var/www/api/usring.wav,ring_ready=true]loopback/$dest/$domain)"};
	$gateway_uuid = $config{gateway_uuid};
	$accountcode = $config{accountcode};
	if ($domain eq 'rapidins.velantro.net'){
		
		$cmd = qq{$fs_cli -x "bgapi originate {ringback=/var/www/api/usring.wav,ignore_early_media=true,absolute_codec_string=PCMA,fromextension=$ext,origination_caller_id_name=$dest,origination_caller_id_number=$dest,effective_caller_id_number=$dest,effective_caller_id_name=$dest,domain_name=$domain,outbound_caller_id_number=$dest,$alert_info,origination_uuid=$uuid,$auto_answer}loopback/$ext/$domain &bridge([origination_caller_id_name=$cid,origination_caller_id_number=$cid,effective_caller_id_number=$cid,effective_caller_id_name=$cid,iscallback=$ext,outbound_caller_id_number=$cid,sip_h_X-accountcode=8706018290]sofia/gateway/$gateway_uuid/$dest))"};
	}
	
	if ($domain eq 'vip.velantro.net' || $doamin eq 'itftrucking.velantro.net'){
		$cmd = qq{$fs_cli -x "bgapi originate {ringback=/var/www/api/usring.wav,ignore_early_media=true,absolute_codec_string=PCMA,fromextension=$ext,origination_caller_id_name=$dest,origination_caller_id_number=$dest,effective_caller_id_number=$dest,effective_caller_id_name=$dest,domain_name=$domain,outbound_caller_id_number=$dest,$alert_info,origination_uuid=$uuid,$auto_answer}user/$ext\@$domain &bridge([origination_caller_id_name=$cid,origination_caller_id_number=$cid,effective_caller_id_number=$cid,effective_caller_id_name=$cid,iscallback=$ext,outbound_caller_id_number=$cid,sip_h_X-accountcode=$accountcode]sofia/gateway/$gateway_uuid/$dest))"};
	}
	
	warn "$cmd\n";
	my $result = `$cmd`;
	if ($query{from} eq 'firefox') {
		template_print($template_file, {error => '0', 'message' => 'ok', 'actionid' => $query{actionid},callbackid => $uuid,dest=>$dest, src => $ext});
	} else {
		sleep 1;
		print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid},callbackid => $uuid});
	}

}



sub get_outbound_callerid {
	my $domain = shift;
	my $ext	= shift;
	
	my $sql = "select * from v_extensions where user_context='$domain' and extension='$ext'";
	#warn $sql;
	my $sth = $dbh->prepare($sql);
	$sth   -> execute();
	my $row = $sth->fetchrow_hashref;
	#warn Dump($row);
	return $row->{outbound_caller_id_number};
}

sub do_checkextension {
	my $domain		= $cgi->server_name();
	my $ext	= $query{extension};
	my $sql = "select * from v_extensions where user_context='$domain' and extension='$ext'";
	#warn $sql;
	my $sth = $dbh->prepare($sql);
	$sth   -> execute();
	my $row = $sth->fetchrow_hashref;
	#warn Dump($row);
	$found =  $row ? 'true' : 'false';
	print j({found => $found});
}
sub start_moh {
	my $uuid = $query{uuid};
	my $path = "/usr/local/freeswitch/sounds/music/8000/$query{widgetid}.wav";
	my $res = `fs_cli -x "uuid_broadcast $uuid $path"`;

	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}});
}

sub stop_moh {
	my $uuid = $query{uuid};
	my $uuid2 = $query{otheruuid};
	
	my $res = `fs_cli -x "uuid_bridge $uuid $uuid2"`;

	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}});
}

sub do_hold () {
    local ($uuid) = substr $query{uuid}, 0, 50;
    local  $direction = $query{direction} eq 'inbound' ? 'inbound': 'outbound';
		 
    if ($direction eq 'outbound') {
		$output = &runswitchcommand("internal", "uuid_hold toggle $uuid");
    	$uuid = &get_bchannel_uuid($uuid);
    }
    warn "uuid_hold toggle $uuid";
    $output = &runswitchcommand("internal", "uuid_hold toggle $uuid");
    
    print j({error => '0', 'message' => $output, 'actionid' => $query{actionid}});
}

sub do_unhold() {
    &do_hold();
}
	
sub do_cdr() {
	local $did = substr $query{did}, 0, 20;
	local $caller_id_number = substr $query{caller_id_number}, 0, 20;
	local $destination_number = substr $query{destination_number}, 0, 20;
	local $st = substr $query{start_stamp}, 0, 20;
	local $et = substr $query{end_stamp}, 0, 20;
	local $uuid = substr $query{uuid}, 0, 100;
	local $page = $query{page} || 0;
	local $limit = $query{limit} || 100;
	$s = $page * $limit;
	
	$st =~ s/\+/ /g;
	$et =~ s/\+/ /g;
	
	@v = localtime();
	$date = sprintf("%04d-%02d-%02d", 1900+$v[5],$v[4]+1,$v[3]);
	$tz = `cat /etc/timezone`;chomp $tz;
	if (!$st) {
		$st = "$date 00:00:00$tz";
	}
	if (!$et) {
		$et = "$date 23:59:59$tz";
	}
	
	my $cond = ($did ? "caller_destination like '%$did' and " : '') .
			($destination_number ? " destination_number='$destination_number' and " : '').			  
			($caller_id_number ? "  caller_id_number like '%$caller_id_number' and " : '') .
			($uuid ? "  xml_cdr_uuid = '$uuid' and " : '') .
			"  start_stamp >= '$st' and end_stamp <= '$et' ";
			
	if ($uuid) {
		$cond = "  xml_cdr_uuid = '$uuid' ";
	}
	
	my $sql = "select count(*) as total from v_xml_cdr where $cond";
			
			
			
	warn $sql;
	my $sth = $dbh->prepare($sql);
	$sth   -> execute();
	$row = $sth->fetchrow_hashref;
	$c = $row->{total};
	
	$sql = "select * from v_xml_cdr where $cond order by start_stamp desc limit $limit offset $s";
	$sth = $dbh->prepare($sql);
	$sth   -> execute();
	#$c = 0;
	$list = [];
	while ($row = $sth->fetchrow_hashref) {
		#$c++;
		$recording_url = '';
		$recording_filename = $row->{record_path} . '/' . $row->{record_name};
		if (!$row->{record_name}) {
			@today = &get_today();
			$recording_filename = "/var/lib/freeswitch/recordings/" . $row->{domain_name} . "/archive" . "/"  . $today[0] . "/" . $today[1] . "/" . $today[2] . "/" . $row->{xml_cdr_uuid};
			if (-e "$recording_filename.mp3") {
				$recording_filename .= ".mp3";
			} elsif(-e "$recording_filename.wav") {
				$recording_filename .= ".wav";
			} else {
				warn $recording_filename . ".mp3|.wav not found";
			}		
		}
		warn "recording_filename: $recording_filename";
		$recording_url = "/app/recordings/recordings2.php?filename=" . encode_base64($recording_filename, '');
		$record_size = -s $recording_filename;
		push @$list, {xml_cdr_uuid => $row->{xml_cdr_uuid}, domain_name => $row->{domain_name}, caller_id_number => $row->{caller_id_number},caller_id_name => $row->{caller_id_name},
					  destination_number => $row->{destination_number}, did => $row->{caller_destination}, start_stamp => $row->{start_stamp}, end_stamp => $row->{end_stamp},
					  billsec => $row->{billsec},duration => $row->{duration},reocrd_size => $record_size || 0,record_url => $recording_url};
	}
	
	
	 print j({error => '0', 'message' => $output, 'actionid' => $query{actionid}, total => $c, list => $list});
}


sub hangup {
	my $uuid = $query{uuid} || $query{callbackid};

=pod	
	my $channels = `fs_cli -x "show channels"`;
	my $uuid_found = 0;
	for (split /\n/, $channels) {
		($id) = split ',', $_;
		if ($id eq $uuid) {
			$uuid_found = 1;
			last;
		}
	}
	if (!$uuid_found) {
		warn "not found $uuid in current channels, let's find it in cdr";
		my $sth = $dbh->prepare("select bridge_uuid from v_xml_cdr where uuid=?");
		$sth->execute($uuid);
		my $row = $sth->fetchrow_hashref;
		if ($row->{bridge_uuid}) {
			$uuid = $row->{bridge_uuid};
		} else {
			print j({error => '1', 'message' => 'Error: not found this callbackid', 'actionid' => $query{actionid}, channels => $channels});
		}
	}
=cut
	my $cmd = "fs_cli -x \"uuid_kill $uuid\"";
	my $res = `$cmd`;
	warn "$cmd: $res\n";
	if ($res =~ /ERR/) {
		warn "not found $uuid in current channels, let's find it in xml_cdr log";
		my $dir = "/usr/local/freeswitch/log/xml_cdr";
		my $xml_file = "$dir/a_$uuid.cdr.xml";
		if (-e $xml_file) {
			$xml =`cat $xml_file`;
			$uuid = getvalue('bridge_uuid', $xml);
			
			warn "bridge_uuid: $uuid";
			if ($uuid{$uuid}) {
				$state = 'DESTANSWERED';
			} else {
				print j({error => '1', 'message' => 'Error: not found this callbackid', 'actionid' => $query{actionid}, channels => $channels});
				exit 0;
			}
		} else {
			warn "not found $uuid in current channels, let's find it in v_xml_cdr_table";
			my $sth = $dbh->prepare("select bridge_uuid from v_xml_cdr where uuid=?");
			$sth->execute($uuid);
			my $row = $sth->fetchrow_hashref;
			if ($row->{bridge_uuid}) {
				$uuid = $row->{bridge_uuid};
			} else {
				print j({error => '1', 'message' => 'Error: not found this callbackid', 'actionid' => $query{actionid}, channels => $channels});
				exit 0;
			}
		}
	}
	$res = `fs_cli -x "uuid_kill $uuid"`;
	

	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}});
	
	
	
}

sub do_transfer {
	my $uuid = $query{uuid} || $query{callbackid};
	my $dest = $query{dest};
	my $domain		= $cgi->server_name();

	if (!$dest) {
		print j({error => '1', 'message' => 'transfer: failed - dest is null', 'actionid' => $query{actionid}});
		exit 0;
		
	}
	
	
	my $leg = '';
	if ($query{direction} eq 'incoming') {
		my $channels = `fs_cli -x "show channels"`;
		my $uuid_found = 0;
		for (split /\n/, $channels) {
			my ($id, $dir) = split ',', $_;
			if ($id eq $uuid) {
				$uuid_found = 1;
				if ($dir eq 'outbound') {
					$leg = '-bleg';
				}
				last;
			}
		}
	} else {
		$leg = '-bleg';
	}
	
	$res = `fs_cli -x "uuid_transfer $uuid  $leg $dest XML $domain"`;
	
	print j({error => '0', 'message' => 'transfer: ok', 'actionid' => $query{actionid}});
}

sub get_callbackstate {
	my $uuid = $query{uuid} || $query{callbackid};

	my %uuid = ();
	my $channels = `fs_cli -x "show channels"`;
	my $uuid_found = 0;
	$i = 0;
	$callstate_index = 24;
	for $channel (split /\n/, $channels) {
		if ($i++ == 0) {
			$j = 0;
			for $field_name (split ',', $channel) {
				if ($field_name eq 'callstate') {
					$callstate_index = $j;
					last;
				}
				$j++;
				
			}
			next;
		}
		
		#warn $callstate_index;
		#@f = split ',', $_;
		$f = records($channel);
		$uuid{$$f[0]} = $$f[$callstate_index];
		if ($$f[0] eq $uuid) {
			$uuid_found = 1;
			$state = $$f[$callstate_index];
			last;
		}
	}
	
	if (!$uuid_found) {
		warn "not found $uuid in current channels, let's find it in cdr";
		my $sth = $dbh->prepare("select bridge_uuid from v_xml_cdr where uuid=?");
		$sth->execute($uuid);
		my $row = $sth->fetchrow_hashref;
		if ($row->{bridge_uuid}) {
			$uuid = $row->{bridge_uuid};
			if ($uuid{$uuid}) {
				$state = 'DESTANSWERED';
			} else {
				$state = 'HANGUP'
			}
		} else {
			$state = 'HANGUP';
		}		warn "not found $uuid in current channels, let's find it in xml_cdr log";
		my $dir = "/usr/local/freeswitch/log/xml_cdr";
		my $xml_file = "$dir/a_$uuid.cdr.xml";
		if (-e $xml_file) {
			$xml =`cat $xml_file`;
			my $uuid = getvalue('bridge_uuid', $xml);
			
			warn "bridge_uuid: $uuid";
			if ($uuid{$uuid}) {
				$state = 'DESTANSWERED';
			} else {
				$state = 'HANGUP';
				warn join ',', keys %uuid;

			}
			
		} else {
			warn "not found $uuid in current channels, let's find it in v_xml_cdr table";
			my $sth = $dbh->prepare("select bridge_uuid from v_xml_cdr where uuid=?");
			$sth->execute($uuid);
			my $row = $sth->fetchrow_hashref;
			if ($row->{bridge_uuid}) {
				$tmp_uuid = $row->{bridge_uuid};
				if ($uuid{$tmp_uuid}) {
					$state = 'DESTANSWERED';
				} else {
					$state = 'HANGUP'
				}
			} else {
				warn "not found $uuid in v_xml_table, we think the state is HANGUP";
				$state = 'HANGUP';
			}
		}
		
	} else {
		warn "$uuid:$state!";
		if ($state eq 'EARLY') {
			$state = 'EXTRING';
		} elsif ($state eq 'RING_WAIT') {
			$state = 'DESTRING';
		} elsif ($state eq 'ACTIVE') {
			$state = 'DESTANSWERED';
		} elsif ($state eq 'HELD') {
			$state = 'HELD';
		} else {
			$state = 'EXTWAIT';
		}
	#	$state = 'HANGUP';
	}
	
	warn "$uuid state: $state";
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}, state => $state});	
}

sub get_channeldetail {
	#uuid,direction,created,created_epoch,name,state,cid_name,cid_num,ip_addr,dest,application,application_data,dialplan,context,read_codec,read_rate,read_bit_rate,write_codec,write_rate,write_bit_rate,secure,hostname,presence_id,presence_data,callstate,callee_name,callee_num,callee_direction,call_uuid,sent_callee_name,sent_callee_num
#d9f255f8-040c-4a49-800d-9fdb1e4e87df,inbound,2014-05-19 23:41:35,1400568095,sofia/internal/100195@vconnect.velantro.net,CS_EXECUTE,100195,100195,140.206.155.127,8882115404,bridge,sofia/gateway/vconnect.velantro.net-a2b/888882115404,XML,vconnect.velantro.net,PCMU,8000,64000,PCMU,8000,64000,srtp:dtls:AES_CM_128_HMAC_SHA1_80,manage1,100195@vconnect.velantro.net,,ACTIVE,Outbound Call,888882115404,SEND,d9f255f8-040c-4a49-800d-9fdb1e4e87df,Outbound Call,888882115404
#231e5597-058b-4516-9573-d7a6a0886bc3,outbound,2014-05-19 23:41:35,1400568095,sofia/external/888882115404,CS_EXCHANGE_MEDIA,8183948767,8183948767,140.206.155.127,888882115404,,,XML,vconnect.velantro.net,PCMU,8000,64000,PCMU,8000,64000,,manage1,,,ACTIVE,Outbound Call,888882115404,SEND,d9f255f8-040c-4a49-800d-9fdb1e4e87df,8183948767,8183948767

	#2 total.
	my $uuid = $query{uuid};
	my $channels = `fs_cli -x "show channels"`;
	
	my $widgetid = '';
	my $ip = '';
	for my $line (split /\n/, $channels) {
		my @f = split ',', $line;
		next if $f[0] =~ /\-/ || $f[0] =~ /^\d+$/;
		next unless $uuid eq $f[0];
		
		#select widgetid from vconnect_widget,v_extensions where vconnect_widget.extension_uid=v_extensions.extension_uuid and user_context='vconnect.velantro.net' and extension='100326'
		my $sth = $dbh->prepare("select widgetid from vconnect_widget,v_extensions where vconnect_widget.extension_uid=v_extensions.extension_uuid and user_context='$HOSTNAME' and extension='$f[7]' limit 1");
		$sth -> execute();
		my $row = $sth->fetchrow_hashref();
		$widgetid = $row->{widgetid};
		
		$ip = $f[8];		
	}
	
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}, ip => $ip, widgetid => $widgetid});
	
}

sub get_tenant {
	my $key = $query{k};
	my $val = $query{v};
	
	my $sth = '';
	if ($key eq 'name') {
		$sth = $dbh->prepare("select domain_name from v_domains where domain_name like '%$val%'");
	} elsif ($key eq 'did') {
		$sth = $dbh->prepare("select domain_name  from v_dialplans, v_domains where v_dialplans.domain_uuid=v_domains.domain_uuid and dialplan_context='public' and dialplan_number like '%$val%'");
		
	}
	
	$sth->execute();
	
	my $list = [];
	my $found = 0;
	while (my $row = $sth->fetchrow_hashref) {
		push @$list, $row->{domain_name};
		$found = 1;
	}
	
	if ($found) {
		print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}, ip => $cgi->server_name(), list => $list});
	} else {
		print j({error => '1', 'message' => 'not found', 'actionid' => $query{actionid}, ip => $cgi->server_name(), list => $list});		
	}
}

sub get_tenant_html {
	my $key = $query{k};
	my $val = $query{v};
	my $sth = $dbh->prepare("select default_setting_value from v_default_settings where default_setting_category='server' and default_setting_subcategory='pbx_list'");
	
	$sth->execute();
	
	my @servers = (); #('67.215.233.19', '67.215.240.10', '67.215.244.204', '67.215.243.244', '67.215.243.245', '67.215.243.245');
	
	my $row = $sth->fetchrow_hashref;
	
	push @servers, split(',', $row->{default_setting_value});
		
	if (!$key) {
		print
"<form>
<input type=hidden name=k value=name>
<input type=hidden name=action value=gettenanthtml>

<input name=v value='' placeholder='tenantname'>
<input type=submit value='search'>
</form>
<form action='api.pl?action=gettenanthtml'>
<input type=hidden name=k value=did>
<input type=hidden name=action value=gettenanthtml>

<input name=v value='' placeholder='DID number'>
<input type=submit value='search'>

</form>		
		";
		exit 0;
	}
	
	print " <table>";
	for my $s (@servers) {
		warn "http://$s/api/api.pl?action=gettenant&k=$key&v=$val";
		my $json = `curl -k -s "http://$s/api/api.pl?action=gettenant&k=$key&v=$val"`;
		my $hash = decode_json($json);
		
		if ($hash->{error}) {
			next;
		}
		
		for (@{$hash->{list}}) {
			print "<tr><td>$_</td><td>$hash->{ip}</td></tr>\n";
		}
	}
	print "</table>\n";
}

sub get_incoming {
	my $ext = $query{ext};
	my $domain  = $query{domain} || $HOSTNAME;
	$domain		= $cgi->server_name();
	$ext = "$ext\@$domain";
	my $channels = `fs_cli -x "show channels"`;
	my $cnt      = 0;
	for my $line (split /\n/, $channels) {
		my @f = split ',', $line;
		if ($f[22] eq $ext && $f[33] ) { #presence_id && initial_ip_addr
			print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}, uuid => $f[0],
					 caller => "$f[6] <$f[7]>", start_time => $f[2], current_state => $f[24]});
			exit 0;
		}		
	}
	
	print j({error => '1', 'message' => 'no call'}); 
}



sub get_incoming_event {
	my $ext = $query{ext};
	my $domain  = $query{domain} || $HOSTNAME;
	$domain		= $cgi->server_name();
	$ext = "$ext\@$domain";
	
	$tid = _uuid();	$ext_tid = "$ext-$tid";

	use Cache::Memcached;
	my $memcache = "";
    my $memcache = new Cache::Memcached {'servers' => ['127.0.0.1:11211'],};
	
	$memcache->delete($ext_tid);

	my $starttime = time;
	local $| = 1;
CHECK:
	
	if (time - $starttime > $max_incoming_event_duration) {
		$memcache->delete($ext_tid);
		exit 0; #force max connection time to 1h
	}
	
	my $status = $memcache->get($ext_tid);
	my $current_state = '';
	
	my $channels = `fs_cli -x "show channels"`;
	my $cnt      = 0;
	my $i = 0;
	my $state_index = 24;
	for my $line (split /\n/, $channels) {
		if ($i++ == 0) {
			if ($line =~ /,accountcode,/) {
				$state_index = 25;
			} else {
				$state_index = 24;
			}
			#warn "state_index:$state_index";

		}

		my @f = split ',', $line;
		if ($f[22] eq $ext && $f[33] && $f[1] eq 'outbound') { #presence_id && initial_ip_addr
			
			$current_state = $f[$state_index];
			if ($status ne $current_state) {		
				print "data:",j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}, uuid => $f[0],
					 caller => "$f[6] <$f[7]>", start_time => $f[2], current_state => $current_state}), "\n\n";
				$memcache->set($ext_tid, $current_state);
			}
		}		
	}
	
	if (!$current_state) {
		if (!$status) {
			
			print "data:" , j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}, uuid => '',
					 caller => "", start_time => '', current_state => 'nocall'}), "\n\n";
			$memcache->set($ext_tid, 'nocall');
		} elsif ($status ne 'nocall') {
			print "data:", j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}, uuid => '',
					 caller => "", start_time => '', current_state => 'hangup'}), "\n\n";
			$memcache->set($ext_tid, '');
		}
	}
	
	sleep 1;
	goto CHECK;
}

sub do_upload_voicemaildrop {
	my $name = uri_unescape(clean_str($query{name}, 'SQLSAFE'));
	my $format = clean_str($query{format}, 'SQLSAFE') || 'mp3';
	my $ext =  clean_str($query{ext}, 'SQLSAFE') || '';
	my $uuid = _uuid();
	my $domain		= $cgi->server_name();
	
	my $basedir = "/usr/local/freeswitch/voicemaildrop";
	if (!-d $basedir) {
		system("mkdir -p $basedir");
	}
	
	my $path = "$basedir/$uuid.$format";
	my $ok = $cgi->upload('voicemaildropfile',  $path);
	my $msg = 'ok';
	my $error = 0;
	if (!$ok) {
        $msg =  $cgi->cgi_error();
		$error = 1;
    }
	
	$dbh->prepare("insert into v_voicemaildrop (voicemaildrop_uuid, voicemaildrop_name, voicemaildrop_path, domain_name, ext) values ('$uuid', '$name', '$path', '$domain', '$ext')")->execute();
	print j({error => $error, 'message' => $msg, 'actionid' => $query{actionid}, id => $uuid});
}

sub do_list_voicemaildrop {
	my $domain		= $cgi->server_name();
	my $ext =  clean_str($query{ext}, 'SQLSAFE') || '';

	my $sth = $dbh->prepare("select * from v_voicemaildrop where domain_name='$domain' and ext='$ext'");
	$sth->execute();
	
	my $list = [];
	my $found = 0;
	while (my $row = $sth->fetchrow_hashref) {
		($type) = $row->{voicemaildrop_path} =~ /\.(\w+)$/;
		$filepath = "voicemaildrop/" . $row->{voicemaildrop_uuid} . ".$type";
		push @$list, {id => $row->{voicemaildrop_uuid}, name => $row->{voicemaildrop_name}, filepath => $filepath};
		$found = 1;
	}
	
	if ($found) {
		print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}, list => $list});
	} else {
		print j({error => '1', 'message' => 'not found', 'actionid' => $query{actionid}, ip => $cgi->server_name(), list => $list});		
	}
}

sub do_delete_voicemaildrop {
	my $id = clean_str($query{id}, 'SQLSAFE');
	my $sth = $dbh->prepare("select * from v_voicemaildrop where voicemaildrop_uuid='$id' ");
	$sth->execute();

	my $list = [];
	my $found = 0;
	my $path  = '';
	while (my $row = $sth->fetchrow_hashref) {
		$path = $row->{voicemaildrop_path};
		$found = 1;
	}
	
	if ($found) {
		$dbh->prepare("delete from v_voicemaildrop where voicemaildrop_uuid='$id' ")->execute;
		unlink $path;
		print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}});

	} else {
		print j({error => '1', 'message' => 'not found', 'actionid' => $query{actionid}});
	}
}

sub do_get_voicemaildrop {
	my $id = clean_str($query{id}, 'SQLSAFE');
	warn $id;
	my $sth = $dbh->prepare("select * from v_voicemaildrop where voicemaildrop_uuid='$id' ");
	$sth->execute();
	my $list = [];
	my $found = 0;
	my $path  = '';
	while (my $row = $sth->fetchrow_hashref) {
		$path = $row->{voicemaildrop_path};
		$found = 1;
	}
	my $filepath = '';
	if ($found) {
		($type) = $path =~ /\.(\w+)$/;
		$filepath = "voicemaildrop/$id.$type";
		print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}, filepath => $filepath, name => $row->{voicemaildrop_name}});

	} else {
		print j({error => '1', 'message' => 'not found', 'actionid' => $query{actionid}});
	}
	
}

sub do_update_voicemaildrop {
	my $id = clean_str($query{id}, 'SQLSAFE');
	my $name = uri_unescape(clean_str($query{name}, 'SQLSAFE'));
	my $sth = $dbh->prepare("update  v_voicemaildrop set voicemaildrop_name='$name' where voicemaildrop_uuid='$id' ");
	$sth->execute();
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}});
}

sub do_send_voicemaildrop {
	my $id = clean_str($query{id}, 'SQLSAFE');
	my $callback_uuid = clean_str($query{callback_uuid}, 'SQLSAFE');
	
	
	my $sth = $dbh->prepare("select * from v_voicemaildrop where voicemaildrop_uuid='$id' ");
	$sth->execute();

	my $list = [];
	my $found = 0;
	my $path  = '';
	while (my $row = $sth->fetchrow_hashref) {
		$path = $row->{voicemaildrop_path};
		$found = 1;
	}
	
	if ($found) {
		my $channels = `fs_cli -x "show calls"`;
		my $cnt      = 0;
		for my $line (split /\n/, $channels) {
			my @f = split ',', $line;
			if ($f[0] eq $callback_uuid ) { #presence_id && initial_ip_addr
				
				$call_found = 1;
				$b_uuid_index = &_call_field2index('b_uuid');
				$remote_uuid = $f[$b_uuid_index];
			}		
		}
		
		if (!$call_found || !$remote_uuid) {
			print j({error => '1', 'message' => "$callback_uuid not found in any call", 'actionid' => $query{actionid}});
		} else {
		
			my $result = `fs_cli -x "uuid_setvar $remote_uuid  voicemaildrop_file $path"`;
			$result = `fs_cli -x "uuid_transfer $remote_uuid play_voicemaildrop XML default"`;
			print j({error => '0', 'message' => $result, 'actionid' => $query{actionid}});
		}
	} else {
		print j({error => '1', 'message' => 'not found', 'actionid' => $query{actionid}});
	}
}

sub getvalue {
	my $key = shift || return;
	my $buffer = shift;
	if ($buffer =~ /\<\?xml/) {
		my($value) =  $buffer =~ m{<$key>(.*?)</$key>}s;
		warn $value;
		return defined $value ? $value : '';
	} else { 
		my ($value) = $buffer =~ /$key=(.+)$/m;
		return defined $value ? $value : '';
	}
}

sub get_today {
	my @arr = localtime();
	my $y   = $arr[5] + 1900;
	my @months = qw/Jan Feb Mar Api May Jun Jul Aug Sep Oct Nov Dec/;
	my $m	= $months[$arr[4]];
	my $d	= sprintf("%02d", $arr[3]);
	
	return ($y, $m, $d);
}

sub _uuid {
	my $str = `uuid`;
	$str =~ s/[\r\n]//g;
	
	return $str;
}

sub _call_field2index {
	my $f = shift || return -1;
	if (-d '/var/lib/freeswitch') {
		$calls_string = 'uuid,direction,created,created_epoch,name,state,cid_name,cid_num,ip_addr,dest,presence_id,presence_data,accountcode,callstate,callee_name,callee_num,callee_direction,call_uuid,hostname,sent_callee_name,sent_callee_num,b_uuid,b_direction,b_created,b_created_epoch,b_name,b_state,b_cid_name,b_cid_num,b_ip_addr,b_dest,b_presence_id,b_presence_data,b_accountcode,b_callstate,b_callee_name,b_callee_num,b_callee_direction,b_sent_callee_name,b_sent_callee_num,call_created_epoch';
	} else {
		$calls_string = 'uuid,direction,created,created_epoch,name,state,cid_name,cid_num,ip_addr,dest,presence_id,presence_data,callstate,callee_name,callee_num,callee_direction,call_uuid,hostname,sent_callee_name,sent_callee_num,b_uuid,b_direction,b_created,b_created_epoch,b_name,b_state,b_cid_name,b_cid_num,b_ip_addr,b_dest,b_presence_id,b_presence_data,b_callstate,b_callee_name,b_callee_num,b_callee_direction,b_sent_callee_name,b_sent_callee_num,call_created_epoch';
	}
	
	my @fields = split ',', $calls_string;
	my $i = 0;	
	for (@fields) {
		return $i if $_ eq $f;
		$i++;
	}
	
	return -1;
}

sub template_print {
	my $template_file = shift;
	my $var = shift;
	
	if ($$var{error} == 1) {
		print "Error: $$var{message}";
		
		exit 0;
	}
	my $html = `cat $template_file`;
	
	$html =~ s/\[% error %\]/$$var{error}/g;
	$html =~ s/\[% callbackid %\]/$$var{callbackid}/g;
	$html =~ s/\[% message %\]/$$var{message}/g;
	$html =~ s/\[% dest %\]/$$var{dest}/g;
	$html =~ s/\[% src %\]/$$var{src}/g;
	
	print $html;
}

sub records {
        my $line   = shift || return;
        my $limit  = shift;
        my $token  = "saaaazh_";
        my $i      = 0;
        my @temp   = ();
        my @fields = ();
        $line =~ s/\[(.*?)\]/$temp[$i]=$1;$token.$i++/gxe;
        for my $f (split ',', $line) {
                if ($f =~ /$token(\d+)/) {
                        $f = $temp[$1];
                }
                push @fields, $f;
        }

        return \@fields;
}


sub clean_str() {
  #limpa tudo que nao for letras e numeros
  local ($old,$extra1,$extra2)=@_;
  local ($new,$extra,$i);
  $old=$old."";
  $new="";
  $caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-_.".$extra1; 		# new default
  $caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-_. @".$extra1; 	# using old default to be compatible with old cgi
  if ($extra1 eq "MINIMAL") {$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890".$extra2;}
  if ($extra2 eq "MINIMAL") {$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890".$extra1;}
  if ($extra1 eq "URL") 	{$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\%".$extra2;}
  if ($extra2 eq "URL") 	{$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\%".$extra1;}
  if ($extra1 eq "SQLSAFE") {$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\% ".$extra2;}
  if ($extra2 eq "SQLSAFE") {$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\% ".$extra1;}
  if ($extra1 eq "TEXT") 	{$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\% ".$extra2;}
  if ($extra2 eq "TEXT") 	{$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\% ".$extra1;}
  if ($extra1 eq "PASSWORD"){$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\%".$extra2;}
  if ($extra2 eq "PASSWORD"){$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\%".$extra1;}
  if ($extra1 eq "EMAIL")	{$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\%".$extra2;}
  if ($extra2 eq "EMAIL")	{$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\%".$extra1;}
  for ($i=0;$i<length($old);$i++) {if (index($caracterok,substr($old,$i,1))>-1) {$new=$new.substr($old,$i,1);} }
  if ($extra1 eq "SQLSAFE") { $new= &clean_str_helper($new) }
  if ($extra2 eq "SQLSAFE") { $new= &clean_str_helper($new) }
  return $new;
}

sub clean_str_helper{
	my $string = @_[0];
	$string =~ s/\\/\\\\/g ; # first escape all backslashes or they disappear
	$string =~ s/\n/\\n/g ; # escape new line chars
	$string =~ s/\r//g ; # escape carriage returns
	$string =~ s/\'/\\\'/g; # escape single quotes
	$string =~ s/\"/\\\"/g; # escape double quotes
	return $string ;
}



sub get_bchannel_uuid() {
	local $uuid = shift || return;
	%raw_calls = &parse_calls();
	for (keys %raw_calls) {
		if ($_ eq $uuid) {
			return $raw_calls{$_}{b_uuid};
			last;
		}
	}
	
	return;
}

sub parse_calls () {
	local $header_csv = 'uuid,direction,created,created_epoch,name,state,cid_name,cid_num,ip_addr,dest,presence_id,presence_data,callstate,callee_name,callee_num,callee_direction,call_uuid,hostname,sent_callee_name,sent_callee_num,b_uuid,b_direction,b_created,b_created_epoch,b_name,b_state,b_cid_name,b_cid_num,b_ip_addr,b_dest,b_presence_id,b_presence_data,b_callstate,b_callee_name,b_callee_num,b_callee_direction,b_sent_callee_name,b_sent_callee_num,call_created_epoch';
	
	@header_array = split /,/, $header_csv;
	
	%calls = ();
	$output = &runswitchcommand('internal', 'show calls');
	for (split /\n/, $output) {
		next if /^\s*$/;
		@v = split /,/, $_;
		
		for (0..$#header_array) {
			$calls{$v[0]}{$header_array[$_]} = $v[$_];
		}
	}
	
	return %calls;	
}

sub runswitchcommand {
	$internal = shift;
	$cmd = shift || return '';
	
	$res = `fs_cli -x "$cmd"`;
	return $res;
}
