#!/usr/bin/perl
#======================================================
# load head
#======================================================
use IO::Socket;
#use Switch;
use Data::Dumper;
use DBI;
use Time::Local;
#use Math::Round qw(:all);
use URI::Escape;
#use Net::AMQP::RabbitMQ;
use POSIX qw(strftime);
use MIME::Base64;
require "/var/www/c2capi/bin/default.include.pl";

#======================================================


#======================================================
# config
#======================================================
$conference_host 	= $host_name;
$version 			= "1.0.2";
$debug 				= 0;
$fork 				= 0;
$file_pid 			= "/var/run/app_konference.pid";
$file_log 			= "/tmp/app_konference.log";
$file_log_bkp 		= "/tmp/app_konference.log.bkp";
$host 				= "127.0.0.1";
$port 				= 8021;
$user 				= "dispatchevent";
$secret 			= "dispatch123"; 
$EOL 				= "\015\012";
$BLANK 				= $EOL x 2;
%dtmf_buffer 		= ();
%automute_buffer	= ();
%poll_buffer		= ();
%buffer 			= ();
$default_host = '115.28.137.2';
$host_prefix  = '';
#======================================================
%callback_spool = ();
#warn "tenant: $app{tenant}\nhost: $app{host}\n";


#======================================================
# arguments
#======================================================
$arguments = join(" ",@ARGV);
$arguments = " \L$arguments ";
if (index($arguments," version ") ne -1) {
	print $version . "\n";
	exit;
}
if (index($arguments," log ") ne -1) {
	$debug = 1;
}
if (index($arguments," logverbose ") ne -1) {
	$debug = 1;
	$|=1;
}
if (index($arguments," daemon ") ne -1) {
	$fork = 1;
	$|=1;
}
if (index($arguments," restart ") ne -1) {
	open FILE, "$file_pid " or die $!;
	my @lines = <FILE>;
	foreach(@lines) {
		`kill -9 $_` 
	}
	close(FILE);
	unlink("$file_pid");
}
#======================================================


&refresh_zoho_tokens();

#======================================================
# fork
#======================================================
if ($fork == 1) {
	chdir '/'                 or die "Can't chdir to /: $!";
	#umask 0;
	open STDIN, '/dev/null'   or die "Can't read /dev/null: $!";
	open STDOUT, ">> $file_log" or die "Can't write to $file_log: $!";
	open STDERR, ">> $file_log" or die "Can't write to $file_log: $!";
	defined(my $pid = fork)   or die "Can't fork: $!";
	exit if $pid;
	setsid                    or die "Can't start a new session: $!";
	$pid = $$;
	open FILE, ">", "$file_pid";
	print FILE $pid;
	close(FILE);
}
$t = getTime();
if (index($arguments," restart ") ne -1) {
	print STDERR "$t STATUS: Listener restarted\n";
}
#======================================================

#======================================================
# main loop
#======================================================
my @commands;
reconnect:
$remote = IO::Socket::INET->new(
    Proto => 'tcp',
    PeerAddr=> $host,
    PeerPort=> $port,
    Reuse   => 1
) or die goto reconnect;
$t = getTime();
print STDERR "$t STATUS: Connected\n";
$remote->autoflush(1);
$logres = login_cmd("auth ClueCon$BLANK");
sleep 1;

$logres = login_cmd("event BACKGROUND_JOB CHANNEL_OUTGOING CHANNEL_BRIDGE CHANNEL_HANGUP CHANNEL_HANGUP_COMPLETE MEDIA_BUG_STOP CUSTOM callcenter::info$BLANK");
$eventcount = 0;
%Channel_Spool = ();
local $| = 1;
open $FH, ">> /tmp/incoming_call.log" or die $!;
%channel_spool = ();
%kill_bridged_uuids = ();
%zoho_tokens = ();
%dialed_calls = ();
$need_event_body = 0;
while (<$remote>) {
	
	$_ =~ s/\r\n//g;
	$_ = trim($_);
	if ($_ eq "") {
		if ($finalline =~ /Event\-Name/) {
			# get regular event data
			$finalline = ltrim($finalline);
			#warn $finalline;
			@raw_data = split(/;;/, $finalline);			
			%event = ();
			$t = getTime();
			foreach(@raw_data) {
				@l = split(/\: /,$_);
				$event{$l[0]} = $l[1];
			}
			# expand zenofon extra data at "type" field
			($tmp1,$tmp2,$tmp3,$tmp4) = split(/\|/,$event{Type});
			# call action
			warn $event{'Event-Name'} . ' ==> ' . $event{'CC-Action'}  . "\n";
			&refresh_zoho_tokens();
			for $key (keys %zoho_tokens) {
				log_debug("zoho_keys: $key=" . $zoho_tokens{$key}{access_token});
			}
			if ($event{'Event-Name'} eq "CHANNEL_OUTGOING") {Dial(%event); }
			elsif ($event{'Event-Name'} eq "CHANNEL_BRIDGE")			{ Bridge(%event); }
			elsif ($event{'Event-Name'} eq "CHANNEL_HANGUP")		{ Hangup(%event); }
			elsif ($event{'Event-Name'} eq "CHANNEL_HANGUP_COMPLETE") { End(%event); }
			elsif ($event{'Event-Name'} eq "MEDIA_BUG_STOP") { Recording(%event); }
			elsif ($event{'Event-Subclass'} eq "callcenter%3A%3Ainfo" &&  $event{'CC-Action'} eq 'agent-status-change') {
				&update_agent_status(%event);
			} elsif ($event{'Event-Subclass'} eq "callcenter%3A%3Ainfo" &&  $event{'CC-Action'} eq 'member-queue-start') {
				&qc_start_echo(%event);
			} elsif ($event{'Event-Subclass'} eq "callcenter%3A%3Ainfo" &&  $event{'CC-Action'} eq 'bridge-agent-start') {
				&qc_answer_echo(%event);
			} elsif ($event{'Event-Name'} eq "BACKGROUND_JOB" && $event{'Job-Command'} eq 'originate')			{
				$need_event_body = 1;
				#check_callback(%event);
			}
				
			
			$eventcount++;
		} 
		$finalline="";
	}
	if ($_ ne "") {
		$line = $_;
		if ($need_event_body) {
			$event{body} = $_;
			&check_callback(%event);
			$need_event_body = '';
		}
		
		if ($finalline eq "") {
			$finalline = $line;
		} else {
			$finalline .= ";;" . $line;
		}
	}
}
$t = getTime();
print STDERR "$t STATUS: Connection Died\n";
close $FH;
goto reconnect;
#======================================================


#======================================================
# poll actions
#======================================================
sub Bridge() {
	local(%event) = @_;
	#print "Bridge: " ;
	#print Dumper(\%event);
	warn $event{'Caller-Caller-ID-Number'} . " start talk with  " . $event{'Caller-Callee-ID-Number'};
	local $from = $event{'Caller-Caller-ID-Number'};
	local $caller_name = $event{'Caller-Caller-ID-Name'};
	local $to =  $event{'Caller-Callee-ID-Number'};
	local $uuid = $event{'Channel-Call-UUID'};
	local $did  = $event{'variable_sip_req_user'};
	local $domain_name = '';
	local $variable_bridge_uuid = $event{variable_bridge_uuid};
	
	if ($kill_bridged_uuids{$variable_bridge_uuid}) {
		$cmd = "fs_cli -rx \"uuid_kill $variable_bridge_uuid\"";
		local $domain_name = $event{'variable_domain_name'};
		#$cmd = "fs_cli -rx \"uuid_transfer $variable_bridge_uuid *9196 XML $domain_name\"";
		$res = `$cmd`;
		warn "cmd: $cmd=$res";
		
		delete  $kill_bridged_uuids{$variable_bridge_uuid};
	}
	
	#$uuid =~ s/\-//g;
	
	local $host = ($host_prefix . $event{'Caller-Context'}) || $default_host;
	local $now = &now();
	local $domain_name = $channel_spool{$uuid}{domain_name};
	local $call_type   = $channel_spool{$uuid}{calltype};
	
	if ($event{'variable_cc_agent_uuid'}) {
			$domain_name = `fs_cli -rx "uuid_getvar $uuid domain_name"`;
			chomp $domain_name;
			$call_type = 'queue';
			$agent_uuid = $event{'variable_cc_agent_uuid'};
			$res = `fs_cli -rx "uuid_setvar $agent_uuid originating_leg_uuid $uuid"`;
	}
	
	local %hash = ('from' => $from, 'caller_name' => $caller_name, 'to' => $to, 'domain_name' => $domain_name, 'did' => $did, 'starttime' => $now, 'calltype' => $call_type, 'calluuid' => $uuid, 'callaction' => 'bridge');
	
	
	local $json = &Hash2Json(%hash);
	
	#$cmd = "curl -d 'callerid1=$from&callerid2=$to&callerIdNumber=$from&requestUrl=agi%3A%2F%2F115.28.137.2%2Fincoming.agi&context=from-internal&channel=SIP%2Fa2b-000007b0&vtigersignature=1940898792584673c6e9a8a&callerId=$from&callerIdName=$from&event=AgiEvent&type=SIP&uniqueId=1481543422.1968&StartTime=$now&callUUID=$uuid&callstatus=StartApp' http://$host/vtigercrm/modules/PBXManager/callbacks/PBXManager.php";
	#warn "Send Event: $json\n";
	#$mq->publish(1, "incoming", $json);
	if (not $dialed_calls{$uuid}) {
		return;
	}
	warn "Get Bridged uuid=$uuid\n";
	warn Data::Dumper::Dumper($dialed_calls{$uuid});
	
	$iscallback = $dialed_calls{$uuid};
	$from = $dailed_calls{$uuid}{from} ;
	$to = $dialed_calls{$uuid}{to};
	$ext = $dialed_calls{$uuid}{ext};
	$domain_name = $dialed_calls{$uuid}{domain_name};
	$type = $dialed_calls{$uuid}{type};
	
	$data = "type=$type&state=answered&id=$uuid&from=$from&to=$to";
	&send_zoho_request('callnotify', $ext, $data);	
}

sub Dial() {
	local(%event) = @_;
	#print Dumper(\%event);
	return unless $event{'Channel-Call-State'} eq 'DOWN';
	print Dumper(\%event);

	warn $event{'Caller-Caller-ID-Number'} . ":" . $event{'Other-Leg-Caller-ID-Number'} . " is calling  " . $event{'Caller-Callee-ID-Number'};
	local	$uuid = $event{'Other-Leg-Unique-ID'} ;

	$uuid = $event{'Channel-Call-UUID'} if !$uuid;

	local $from = $event{'Other-Leg-Caller-ID-Number'};
	local $caller_name = $event{'Caller-Caller-ID-Name'};
	
	local $to =  $event{'Caller-Callee-ID-Number'};
	local $caller_destination = $event{'Caller-RDNIS'};
	#$uuid =~ s/\-//g;
	local $now = &now();
	if ($event{'Caller-Context'} eq 'default') {return;}
	local $host = ($host_prefix . $event{'Caller-Context'}) || $default_host;
	
	local $domain_name = `fs_cli -rx "uuid_getvar $uuid domain_name"`;
	chomp $domain_name;
	$domain_name = '' if $domain_name eq '_undef_';

	local $iscallback = `fs_cli -rx "uuid_getvar $uuid iscallback"`;
	chomp $iscallback; $iscallback = '' if $iscallback eq '_undef_';
	if ($iscallback) {
		$from = $event{'Caller-Orig-Caller-ID-Name'};
	}
	
	if ($event{'Caller-Channel-Name'} =~ m{loopback/(\w+)\-a}) {
		$to = $event{'Caller-Destination-Number'};
	}
	if ($event{'Caller-Channel-Name'} =~ m{loopback/(\w+)\-b}) {
		return;
	}
	if ($zoho_tokens{$to.'@' . $domain_name}) {
		$type = 'received';
		$ext = $to.'@' . $domain_name;
	} elsif ($zoho_tokens{$from.'@' . $domain_name}) {
		$type = 'dialed';
		$ext = $from.'@' . $domain_name;
	} else {
		return;
	}
	
	if ($dialed_calls{$uuid}) {
		$iscallback = $dialed_calls{$uuid};
		$from = $dailed_calls{$uuid}{from} ;
		$to = $dialed_calls{$uuid}{to};
		$ext = $dialed_calls{$uuid}{ext};
		$domain_name = $dialed_calls{$uuid}{domain_name};
		$type = $dialed_calls{$uuid}{type};
	} else {	
		$dailed_calls{$uuid}{from} = $from;
		$dialed_calls{$uuid}{to} = $to;
		$dialed_calls{$uuid}{ext} = $ext;
		$dialed_calls{$uuid}{domain_name} = $domain_name;
		$dialed_calls{$uuid}{type} = $type;
		$dialed_calls{$uuid}{iscallback} = $iscallback;
		if ($iscallback && $type eq 'recieved') {
			return;
		}
	}
	$data = "type=$type&state=ringing&id=$uuid&from=$from&to=$to";
	$cache_uuid = &_uuid();
	$now = &now();
	$sql = "insert into v_zoho_api_cache (zoho_api_cache_uuid,ext,data,insert_date) values('$cache_uuid', '$ext', 'type=$type&id=$uuid&from=$from&to=$to','$now')";
	warn $sql;
	&database_do($sql);
	&send_zoho_request('callnotify', $ext, $data);	
}

sub Newchannel() {
	local(%event) = @_;
	$Channel_Spool{$event{Channel}}{CallerIDName} = $event{CallerIDName};
	&log_debug("Get CallerIDName " . $event{Channel} . '=' . $Channel_Spool{$event{Channel}}{CallerIDName} . "!\n");
	$Channel_Spool{$event{Channel}}{Exten} = $event{Exten};
	&log_debug("Get Exten " . $event{Channel} . '=' . $Channel_Spool{$event{Channel}}{Exten} . "!\n");
	
	$Channel_Spool{$event{Channel}}{UniqueID} = $event{Uniqueid};
	&log_debug("Get UniqueID " . $event{Channel} . '=' . $Channel_Spool{$event{Channel}}{UniqueID} . "!\n");
}

sub Hangup() {
	local(%event) = @_;
	warn "Get Hangup";
	return;
	$from = $event{'Caller-Caller-ID-Number'};
	local $caller_name = $event{'Caller-Callee-ID-Name'};
	$to =  $event{'Caller-Callee-ID-Number'};
	$uuid = $event{'Channel-Call-UUID'};
	$causetxt = $event{'Hangup-Cause'};
	#$uuid =~ s/\-//g;
	$host = ($host_prefix . $event{'Caller-Context'}) || $default_host;
	
	$now = &now();
	#$cmd = "curl -d 'server=null&calleridname=$from&channel=SIP%2F801-000007b1&cause=16&vtigersignature=1940898792584673c6e9a8a&privilege=call&sequencenumber=null&calleridnum=$to&causetxt=Normal+Clearing&callerid=$from&systemHashcode=1214198952&event=HangupEvent&uniqueid=1481543423.1969&timestamp=$now&callUUID=$uuid&causetxt=$causetxt&callstatus=Hangup' http://$host/vtigercrm/modules/PBXManager/callbacks/PBXManager.php";
	#warn $cmd;
	#system($cmd);
	
	
}

sub End() {
	local(%event) = @_;
	local $from = $event{'variable_caller_id_number'};
	local $caller_name = $event{'Caller-Caller-ID-Name'};
	local $to =  $event{'variable_callee_id_number'};
	local $domain_name =  $event{'variable_domain_name'};
	local $iscallback =  $event{'variable_iscallback'};
	local $uuid = $event{'Channel-Call-UUID'};
	#$uuid =~ s/\-//g;
	local $duration = $event{'variable_duration'};
	local $billsec  = $event{'variable_billsec'};
	local $endtime	= uri_unescape($event{'variable_end_stamp'});
	local $start_epoch = $event{'variable_start_epoch'};
	local $starttime = uri_unescape($event{'variable_start_stamp'});
	local $host = ($host_prefix . $event{'Caller-Context'}) || $default_host;
	
	warn "Hangup call: $uuid";
	if (not $dialed_calls{$uuid}) {
		return;
	}
	
	if ($event{'Answer-State'} ne 'hangup' || $event{'Channel-Name'} =~ /loopback/) {
		return;
	}
	
	#warn Data::Dumper::Dumper($dialed_calls{$uuid});
	#print Dumper(\%event);
	local $now = &now();
 	
	#warn " $presence_id eq $to\@$domain_name";
	#return unless $presence_id eq "$to\@$domain_name";

	local $recording_filename = "/var/lib/freeswitch/recordings/$domain_name/archive/". strftime('%Y', localtime($start_epoch)) . "/" . strftime('%b',  localtime($start_epoch)) . "/" . strftime('%d', localtime($start_epoch)) .  "/$a_uuid.wav";
	#warn $recording_filename;
	$recording_url = '';
	if (-e $recording_filename) {
		$recording_url = "http://$domain_name/app/recordings/recordings2.php?filename=" . encode_base64($recording_filename, '');
	}
	#warn $recording_url;
	local %hash = ('from' => $from, 'caller_name' => $caller_name, 'to' => $to, 'domain_name' => $domain_name, 'starttime' => $now, 'calltype' => $call_type, 'calluuid' => $uuid, 'callaction' => 'hangup',duration => $duration, billsec => $billsec,starttime => $starttime, endtime => $endtime, 'recording_url' => $recording_url, call_center_queue_uuid => $call_center_queue_uuid, queue => $queue_name);
	

	if ($event{'Caller-Channel-Name'} =~ m{loopback/(\w+)\-a}) {
		$to = $event{'Caller-Destination-Number'};
	}
	
	
	$iscallback = $dialed_calls{$uuid};
	$from = $dailed_calls{$uuid}{from} ;
	$to = $dialed_calls{$uuid}{to};
	$ext = $dialed_calls{$uuid}{ext};
	$domain_name = $dialed_calls{$uuid}{domain_name};
	$type = $dialed_calls{$uuid}{type};
	delete $dialed_calls{$uuid};
	warn "Hangup Call from $from to $to";

	if ($type eq 'recieved' && !$billsec) {
		$state = 'missed';
	} else {
		$state = 'ended';
	}
	$data = "type=$type&state=$state&id=$uuid&from=$from&to=$to&start_time=$starttime&duration=$billsec&voiceuri=https://$domain_name/app/xml_cdr/download.php?id=$uuid"; #uri_escape('https://$domain_name/app/xml_cdr/download.php?id=$uuid&t=bin');
	
	
	&database_do("delete from v_zoho_api_cache where ext='$ext'");
	&send_zoho_request('callnotify', $ext, $data);
}

sub check_callback() {
	print Dumper(\%event);
}

sub update_agent_status() {
	local(%event) = @_;
	local $agent = $event{'CC-Agent'};
	local $status = $event{'CC-Agent-Status'};
	
	local $agent = uri_unescape($agent);
	local $status = uri_unescape($status);
	local $time  = uri_unescape($event{'Event-Date-Local'});
	warn "update $agent status to $status";
	local $uuid = &genuuid();
	local $now	= &now();
	local %break = &database_select_as_hash("select 1, uuid from v_agent_break where agent='$agent' and break_time_end is NULL", 'uuid');
	local $last_open_break_uuid = $break{1}{uuid};
	if ($status ne 'On Break' && $last_open_break_uuid) {
		&database_do("update v_agent_break set break_time_end='$now' where uuid='$last_open_break_uuid'");
	}
	
	if ($status eq 'Available') {
		local $now = &now();
		#&database_do("update v_agent_login set logout_time='$now' where agent='$agent' and logout_time is null");
		local %login = &database_select_as_hash("select 1, uuid from v_agent_login where agent='$agent' and logout_time is NULL", 'uuid');
		if (!$login{1}{uuid}) {
			warn "insert into v_agent_login (uuid,agent,login_time) values ('$uuid', '$agent', '$time')";
			&database_do("insert into v_agent_login (uuid,agent,login_time) values ('$uuid', '$agent', '$time')");
		}
	} elsif ($status eq 'Logged Out') {
		local %data = &database_select_as_hash("select 1,uuid from v_agent_login where agent='$agent' and login_time is not NULL and logout_time is NULL", 'uuid');
=pod		
		if (!$data{1}{uuid}) {
			warn "not found the login time, get the last logout time";
			local %data = &database_select_as_hash("select 1,logout_time from v_agent_login where agent='$agent' and logout_time is not NULL order by logout_time desc limit 1", 'time');
			
				if ($data{1}{time}) {
					$login_time = $data{1}{time};
			
				} else {
					$t = `fs_cli -rx "uptime seconds"`;
					$t =~ s/\D//g;
					$login_time = time - $t;
					$login_time = &now($login_time);

				}

				warn "insert into v_agent_login (uuid,agent,login_time,logout_time) values ('$uuid', '$agent', '$login_time', '$time')";
				&database_do("insert into v_agent_login (uuid,agent,login_time,logout_time) values ('$uuid', '$agent', '$login_time', '$time')");
			}
		} else {
=cut
		if ($data{1}{uuid}) {
			warn "update v_agent_login set logout_time='$time' where uuid='$data{1}{uuid}'";
			&database_do("update v_agent_login set logout_time='$time' where uuid='$data{1}{uuid}'");
		}		
	} elsif ($status eq 'On Break') {
		if (!$last_open_break_uuid) {
			warn "insert into v_agent_break (uuid,agent,break_time_start) values ('$uuid', '$agent', '$now')";
			&database_do("insert into v_agent_break (uuid,agent,break_time_start) values ('$uuid', '$agent', '$now')");
		}
		
	}
	return 1;
}

sub qc_start_echo() {
	local(%event) = @_;
	#local $callback_number = "\*91968888";
	local $cn = $event{'Channel-Name'}; #$event{'variable_caller_id_number'};
	warn "Channel Name: $cn";
	print Dumper(\%event);

	# loopback/*9196888815149991234-a
	#if ($cn =~ m{\*91968888(\d+)}) {
	if ($cn =~ /loopback\/\*91968888\d+\-a/) {
		warn "Start process callback member: $cn\n"
	} else {
		return;
	}
	
	local $original_joined_epoch = $event{'variable_original_joined_epoch'};
	local $original_rejoined_epoch = $event{'variable_original_rejoined_epoch'};
	
	local $dbh = DBI->connect("dbi:SQLite:dbname=/var/lib/freeswitch/db/callcenter.db","","");
	local $uuid = $event{'Channel-Call-UUID'};
	$sql = "update members set joined_epoch=$original_joined_epoch,rejoined_epoch=$original_rejoined_epoch where session_uuid='$uuid'";
	warn $sql;
	$sth = $dbh->prepare($sql);
	$sth->execute();
	
	return 1;
}

sub qc_answer_echo() {
	local(%event) = @_;
	#local $callback_number = "\*91968888";
	local $cn = $event{'CC-Member-DNIS'};
	warn "Member RDNIS: $cn";
	print Dumper(\%event);
	
#*9196888815149991234
	if ($cn =~ m{\*91968888(\d+)}) {
		$origination_caller_id_number = $1;
		warn "Start process callback member: $cn:$1\n"
	} else {
		return;
	}
	
	
	local $uuid = $event{'Channel-Call-UUID'};
	local $domain_name = $event{'variable_domain_name'};
	$cmd = "fs_cli -rx \"sched_transfer +1 $uuid  $origination_caller_id_number XML $domain_name\"";
	$res = `$cmd`;
	warn "cmd: $cmd=$res";
	
	$cmd = "fs_cli -rx \"uuid_display $uuid $origination_caller_id_number\"";
	$res = `$cmd`;
	warn "cmd: $cmd=$res";
	
	$session_uuid = $event{'CC-Member-Session-UUID'};
	warn "MemberSessionUUID=$session_uuid";
	#$cmd = "fs_cli -rx \"uuid_kill $session_uuid\"";
	$kill_bridged_uuids{$session_uuid} = time;
	#$res = `$cmd`;
	#warn "cmd: $cmd=$res";
	
	return 1;
}

sub Recording() {
	local(%event) = @_;
	local $src_presence_id = uri_unescape($event{'Channel-Presence-ID'});
	local ($src, $src_domain) = split '@', $src_presence_id;
	local $cc_agent =  uri_unescape($event{'variable_cc_agent'});
	
	if ($cc_agent) {
		$dst_presence_id = $cc_agent;
		$cc_dst = $event{'variable_last_sent_callee_id_number'};
	} else {	
		$dst_presence_id = uri_unescape($event{'variable_sip_req_uri'});
	}
	local ($dst, $dst_domain) = split '@', $dst_presence_id;
	$dst = $cc_dst if $cc_dst;
	local $dt = uri_unescape($event{'Event-Date-Local'});
	local $recording_file = $event{'Media-Bug-Target'};
	
	if (!-e $recording_file) {
		warn "$recording_file not found, ignore!!\n";
		return;
	}
	
	warn "$recording_file found!!\n";

	local %hash = &database_select_as_hash("select  format('%s@%s',voicemail_id, domain_name) tmpkey, voicemail_mail_to
										   from v_voicemails
										   left join v_domains on v_domains.domain_uuid=v_voicemails.domain_uuid
										   where
										   (voicemail_id='$src' or voicemail_id='$dst') and 
										   (domain_name='$src_domain' or domain_name='$dst_domain')",
										   "voicemail_mail_to,domain_name,voicemail_id");
	
	local $src_to = $hash{$src_presence_id}{voicemail_mail_to} || ''; 
	local $dst_to = $hash{$dst_presence_id}{voicemail_mail_to} || '';
	if ($recording_file =~ /_\d+\.(?:wav|mp3)$/) {
		&send_recording_email($src_to, $dst_to, $recording_file, $src_presence_id, $dst_presence_id, $dt);
	} else {
		warn "$recording_file is not demanded recording, ignore!!!\n";
	}
	
	
	
	return 1;
}

sub send_recording_email () {
	local ($src_to, $dst_to, $recording_file, $src_presence_id, $dst_presence_id, $dt) = @_;
	warn "$src_to, $dst_to, $recording_file, $src_presence_id, $dst_presence_id, $dt!\n";
	local $email_body =<<B;
<html>
<font face="arial">
<b>New Recording From <a href="tel:$src_presence_id"> to "$src_presence_id"  To <a href="tel:$src_presence_id">$dst_presence_id</a></b><br/>
<hr noshade="noshade" size="1"/>
Created: $dt<br/>
src: $src_presence_id<br/>
dst: $dst_presence_id<br/>
</font>
</html>
B

	local $email_subject =<<S;
New Recording  from $src_presence_id to $dst_presence_id
S

    $email_subject =~ s/'/&#39;/g;
	$email_subject =~ s/"/&#34;/g;
    $email_subject =~ s/\n//g;
    
	$email_body =~ s/'/&#39;/g;
	$email_body =~ s/"/&#34;/g;
    $email_body =~ s/\n//g;
	if ($src_to) {
		
		$cmd = "luarun email.lua $src_to $src_to ' ' '$email_subject' '$email_body' '$recording_file' false";
		warn $cmd;
		system("fs_cli -rx \"$cmd\"");
	}
	
	if ($dst_to) {
		$cmd = "luarun email.lua $dst_to $dst_to ' ' '$email_subject' '$email_body' '$recording_file' false";
		warn $cmd;
		system("fs_cli -rx \"$cmd\"");
	}

}

sub refresh_zoho_tokens() {
	%zoho_tokens = &database_select_as_hash("select ext,zohouser,refresh_token,access_token,extract(epoch from update_date) from v_zoho_users where ext is not null", "zohouser,refresh_token,access_token,update_time");
	for $key(keys %zoho_tokens) {

		if (time-$zoho_tokens{$key}{update_time} > 1800) {
			$client_id = '1000.Z7AE3OOFNGE5Y3IJPZGJWK45QWTM0D';
			$client_secret = '9d6bb961106e7e495928b13f6bec05e56c1cbba6dc';
			$refresh_token = $zoho_tokens{$key}{refresh_token};
			$out = `curl -k 'https://accounts.zoho.com/oauth/v2/token' -X POST -d 'refresh_token=$refresh_token&client_id=$client_id&client_secret=$client_secret&grant_type=refresh_token'`;
			%h = &Json2Hash($out);
			if ($h{access_token}) {
				$zoho_tokens{$key}{access_token} = $h{access_token};
				$sql =  "update v_zoho_users set access_token='" . $h{access_token} . "',update_date=now()";
				warn "sql: $sql\n";
				&database_do($sql);
			}
			
			break;
		}
		
	}
}

sub send_zoho_request() {
	local ($type, $ext, $data) = @_;
	if ($type eq 'callnotify') {
		$url = 'https://www.zohoapis.com/phonebridge/v3/callnotify';
	}
	warn "$type, $ext, $data";
	$code = $zoho_tokens{$ext}{access_token};
	$cmd = "curl  $url -X POST -d '$data' -H 'Authorization: Zoho-oauthtoken $code' -H 'Content-Type: application/x-www-form-urlencoded'";
	$res = `$cmd`;
	log_debug("cmd:$cmd\nresponse: $res\n");
	return $res;
}

sub log_debug() {
	$msg = shift;
	$t = getTime();
	print STDERR "$t $msg\n";
}


sub log_sql() {
	$msg = shift;
	$t = getTime();
	open "W", ">> /tmp/log.sql";
	print W "$msg\n";
	close W;
}
#======================================================
# john library
#======================================================
sub command {
        my $cmd = @_[0];
        my $buf="";
        print $remote $cmd;
       return $buf; 
}
sub getTime {
	@months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	@weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
	($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
	$year = 1900 + $yearOffset;
	if ($hour < 10) {
		$hour = "0$hour";
	}
	if ($minute < 10) {
		$minute = "0$minute";
	}
	if ($second < 10) {
		$second = "0$second";
	}
	$theTime = "[$months[$month] $dayOfMonth $hour:$minute:$second]";
	return $theTime; 
}

sub date {
	$mode = shift;
	($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
	
	if ($mode eq 't') {
		return sprintf("%02d:%02d:%02d", $hour, $minute, $second);
	} elsif ($mode eq 'd') {
		return sprintf("%d/%d/%d", $month+1, $dayOfMonth, $yearOffset+1900);
	}
}

sub now {
	$mode = shift;
	($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
	
	return  sprintf("%04d-%02d-%02d %02d:%02d:%02d", $yearOffset+1900, $month+1, $dayOfMonth,  $hour, $minute, $second);
}
sub login_cmd {
        my $cmd = @_[0];
        my $buf="";
        print $remote $cmd;
        return $buf;
}
sub DELETE_trim($) {                                   
        my $string = shift;                     
        $string =~ s/^\s+//;                    
        $string =~ s/\s+$//;            
        return $string;                         
}                                               
sub ltrim($)                             
{                                
        my $string = shift;
        $string =~ s/^\s+//;
        return $string;
}       
sub rtrim($)
{               
        my $string = shift;
        $string =~ s/\s+$//;
        return $string;
}
sub trim {
     my @out = @_;
     for (@out) {
         s/^\s+//;
         s/\s+$//;
     }
     return wantarray ? @out : $out[0];
}

sub _uuid {
	my $str = `uuid`;
	$str =~ s/[\r\n]//g;
	
	return $str;
}

#======================================================
 
