#!/usr/bin/perl
#======================================================
# load head
#======================================================
use IO::Socket;
use Switch;
use Data::Dumper;
use DBI;
use Time::Local;
#use Math::Round qw(:all);
use URI::Escape;
use POSIX qw(strftime);
use MIME::Base64;
$default_include = "/salzh/velantroapi/bin/default.include.pl";
$SIG{CHLD} = \&reaper;
$SIG{INT}          = \&_stop_server;
$SIG{'__DIE__'}    = \&_die;
$SIG{'__WARN__'}   = \&_warn;

$pid = fork();
if ($pid <= 0) {
	&monitor_callback();
	exit;
}

require $default_include;

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

$logres = login_cmd("event CHANNEL_HANGUP CHANNEL_UNHOLD CHANNEL_HOLD$BLANK");
$eventcount = 0;
%Channel_Spool = ();
local $| = 1;
open $FH, ">> /tmp/incoming_call.log" or die $!;
%channel_spool = ();
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
			if ($event{'Event-Name'} eq "CHANNEL_HOLD"   ||
				$event{'Event-Name'} eq "CHANNEL_UNHOLD" ||
				$event{'Event-Name'} eq "CHANNEL_HANGUP") {
				&do_hold(%event);
			} 
			elsif ($event{'Event-Subclass'} eq "callcenter%3A%3Ainfo" &&  $event{'CC-Action'} eq 'agent-status-change') {&update_agent_status(%event);}
				
			
			$eventcount++;
		} 
		$finalline="";
	}
	if ($_ ne "") {
		$line = $_;
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
sub do_hold() {
	local(%event) = @_;
	#print Dumper(\%event); return;
	local $uuid = $event{'Channel-Call-UUID'};
	local $other_uuid = $event{'Other-Leg-Unique-ID'};
	$other_uuid ||= $event{'Caller-Unique-ID'};

	local $time  = uri_unescape($event{'Event-Date-Local'});
	local $presence_id =  uri_unescape($event{'Channel-Presence-ID'});
	local ($ext, $domain_name) = split '@', $presence_id;
	
	if (index(",$app{domain_monitor_hold},", ",$domain,") == -1) {
		return;
	}
	
	
	if ($event{'Event-Name'} eq 'CHANNEL_HOLD') {
		$sql = "insert into v_hold (channel_uuid,other_channel_uuid,hold_timestamp,ext, domain_name) values
				('$uuid', '$other_uuid', now(), '$ext', '$domain_name')";
	} elsif ($event{'Event-Name'} eq 'CHANNEL_UNHOLD' ||
			$event{'Event-Name'} eq "CHANNEL_HANGUP") {
		$sql = "delete from v_hold where channel_uuid='$uuid'";
	}
	warn "sql: $sql!\n";
	&database_do($sql);
	
	return 1;
}

sub Bridge() {
	local(%event) = @_;
	print "Bridge: " ;
	print Dumper(\%event);
	warn $event{'Caller-Caller-ID-Number'} . " start talk with  " . $event{'Caller-Callee-ID-Number'};
	local $from = $event{'Caller-Caller-ID-Number'};
	local $to =  $event{'Caller-Callee-ID-Number'};
	local $uuid = $event{'Channel-Call-UUID'};
	local $domain_name = '';

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
	
	local %hash = ('from' => $from, 'to' => $to, 'domain_name' => $domain_name, 'starttime' => $now, 'calltype' => $call_type, 'calluuid' => $uuid, 'callaction' => 'bridge');
	
	
	local $json = &Hash2Json(%hash);
	
	#$cmd = "curl -d 'callerid1=$from&callerid2=$to&callerIdNumber=$from&requestUrl=agi%3A%2F%2F115.28.137.2%2Fincoming.agi&context=from-internal&channel=SIP%2Fa2b-000007b0&vtigersignature=1940898792584673c6e9a8a&callerId=$from&callerIdName=$from&event=AgiEvent&type=SIP&uniqueId=1481543422.1968&StartTime=$now&callUUID=$uuid&callstatus=StartApp' http://$host/vtigercrm/modules/PBXManager/callbacks/PBXManager.php";
	warn "Send Event: $json\n";
	$mq->publish(1, "incoming", $json);
}

sub Dial() {
	local(%event) = @_;
	print Dumper(\%event);
	return unless $event{'Channel-Call-State'} eq 'DOWN';
	#	print Dumper(\%event);

	warn $event{'Caller-Caller-ID-Number'} . " is calling  " . $event{'Caller-Callee-ID-Number'};
	local	$uuid = $event{'Other-Leg-Unique-ID'} ;

	$uuid = $event{'Channel-Call-UUID'} if !$uuid;

	local $from = $event{'Caller-Caller-ID-Number'};
	local $to =  $event{'Caller-Callee-ID-Number'};
	#$uuid =~ s/\-//g;
	local $now = &now();
	local $host = ($host_prefix . $event{'Caller-Context'}) || $default_host;
	
	local $domain_name = `fs_cli -rx "uuid_getvar $uuid domain_name"`;
	chomp $domain_name;
	$domain_name = '' if $domain_name eq '_undef_';
	local $cc_queue = `fs_cli -rx "uuid_getvar $uuid cc_queue"`;
	chomp $cc_queue;
	
	$cc_queue = '' if $cc_queue eq '_undef_';
	local $ring_group_uuid = `fs_cli -rx "uuid_getvar $uuid ring_group_uuid"`;
	chomp $ring_group_uuid;
	$ring_group_uuid = '' if $ring_group_uuid eq '_undef_';
	local $call_type = 'inbound';
	if ($cc_queue) {
		$call_type = 'queue';
	} elsif ($ring_group_uuid) {
		$call_type = 'ringgroup';
	} elsif (length($from) < 6) {
		$call_type = 'extension';
	} 
	
	$channel_spool{$uuid}{domain_name} = $domain_name;
	$channel_spool{$uuid}{calltype} = $call_type;
	
	if (!$domain_name) {
		local ($queue, $d) = split '@', $cc_queue;
		$domain_name = $d if $d;
	}
	
	if ($domain_name && $cc_queue) {
		local ($queue, $d) = split '@', $cc_queue;
		%hash = &database_select_as_hash("select 1,call_center_queue_uuid from v_call_center_queues left join v_domains on v_call_center_queues.domain_uuid=v_domains.domain_uuid where domain_name='$d' and queue_name='$queue'", 'call_center_queue_uuid');
		$call_center_queue_uuid = $hash{1}{call_center_queue_uuid};
	}
	
	local %hash = ('from' => $from, 'to' => $to, 'domain_name' => $domain_name, 'starttime' => $now, 'calltype' => $call_type, 'calluuid' => $uuid, 'callaction' => 'dial', queue => $cc_queue, call_state =>  $event{'Channel-Call-State'}, call_center_queue_uuid => $call_center_queue_uuid);
	
	
	local $json = &Hash2Json(%hash);
	
	#$cmd = "curl -d 'callerid1=$from&callerid2=$to&callerIdNumber=$from&requestUrl=agi%3A%2F%2F115.28.137.2%2Fincoming.agi&context=from-internal&channel=SIP%2Fa2b-000007b0&vtigersignature=1940898792584673c6e9a8a&callerId=$from&callerIdName=$from&event=AgiEvent&type=SIP&uniqueId=1481543422.1968&StartTime=$now&callUUID=$uuid&callstatus=StartApp' http://$host/vtigercrm/modules/PBXManager/callbacks/PBXManager.php";
	warn "Send Event: $json\n";
	$mq->publish(1, "incoming", $json);
	#warn $cmd;
	#system($cmd);
	
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
	$to =  $event{'Caller-Callee-ID-Number'};
	$uuid = $event{'Channel-Call-UUID'};
	$causetxt = $event{'Hangup-Cause'};
	#$uuid =~ s/\-//g;
	$host = ($host_prefix . $event{'Caller-Context'}) || $default_host;
	
	$now = &now();
	$cmd = "curl -d 'server=null&calleridname=$from&channel=SIP%2F801-000007b1&cause=16&vtigersignature=1940898792584673c6e9a8a&privilege=call&sequencenumber=null&calleridnum=$to&causetxt=Normal+Clearing&callerid=$from&systemHashcode=1214198952&event=HangupEvent&uniqueid=1481543423.1969&timestamp=$now&callUUID=$uuid&causetxt=$causetxt&callstatus=Hangup' http://$host/vtigercrm/modules/PBXManager/callbacks/PBXManager.php";
	warn $cmd;
	system($cmd);
}

sub End() {
	local(%event) = @_;
	local $from = $event{'Caller-Caller-ID-Number'};
	local $to =  $event{'Caller-Callee-ID-Number'};
	local $uuid = $event{'Channel-Call-UUID'};
	#$uuid =~ s/\-//g;
	local $duration = $event{'variable_duration'};
	local $billsec  = $event{'variable_billsec'};
	local $endtime	= uri_unescape($event{'variable_end_stamp'});
	local $start_epoch = $event{'variable_start_epoch'};
	local $starttime = uri_unescape($event{'variable_start_stamp'});
	local $host = ($host_prefix . $event{'Caller-Context'}) || $default_host;
	warn "Get Hangup-Complete " . $uuid;
									
	#print Dumper(\%event);
	local $now = &now();
 	local $a_uuid = $event{'variable_originating_leg_uuid'};

	if (!$event{'variable_cc_member_uuid'}) {
		
		return unless $a_uuid;
		warn $a_uuid;
	}
	$presence_id =  uri_unescape($event{'variable_presence_id'});
	
	local $domain_name = $channel_spool{$uuid}{domain_name} ||  $channel_spool{$a_uuid}{domain_name};
	
	local $call_type   = $channel_spool{$uuid}{calltype} || $channel_spool{$a_uuid}{calltype};
	$domain_name = '' if $domain_name eq '_undef_';

	if (!$domain_name) {
		$domain_name = $event{'variable_domain_name'};
		if ($event{'variable_cc_queue'}) {
			$call_type = 'queue';
		}
	}
	
	
	return unless $presence_id eq "$to\@$domain_name";
	warn $event{'Caller-Caller-ID-Number'} . " end call with  " . $event{'Caller-Callee-ID-Number'};
	$queue_name = $event{'variable_cc_queue'};
	if ($queue_name) {
		local ($queue, $d) = split '@', $queue_name;
		%hash = &database_select_as_hash("select 1,call_center_queue_uuid from v_call_center_queues left join v_domains on v_call_center_queues.domain_uuid=v_domains.domain_uuid where domain_name='$d' and queue_name='$queue'", 'call_center_queue_uuid');
		$call_center_queue_uuid = $hash{1}{call_center_queue_uuid};
	}
	local $recording_filename = "/var/lib/freeswitch/recordings/$domain_name/archive/". strftime('%Y', localtime($start_epoch)) . "/" . strftime('%b',  localtime($start_epoch)) . "/" . strftime('%d', localtime($start_epoch)) .  "/$a_uuid.wav";
	#warn $recording_filename;
	$recording_url = '';
	if (-e $recording_filename) {
		$recording_url = "http://$domain_name/app/recordings/recordings2.php?filename=" . encode_base64($recording_filename, '');
	}
	#warn $recording_url;
	local %hash = ('from' => $from, 'to' => $to, 'domain_name' => $domain_name, 'starttime' => $now, 'calltype' => $call_type, 'calluuid' => $uuid, 'callaction' => 'hangup',duration => $duration, billsec => $billsec,starttime => $starttime, endtime => $endtime, 'recording_url' => $recording_url, call_center_queue_uuid => $call_center_queue_uuid, queue => $queue_name);
	
	
	local $json = &Hash2Json(%hash);
	
	#$cmd = "curl -d 'callerid1=$from&callerid2=$to&callerIdNumber=$from&requestUrl=agi%3A%2F%2F115.28.137.2%2Fincoming.agi&context=from-internal&channel=SIP%2Fa2b-000007b0&vtigersignature=1940898792584673c6e9a8a&callerId=$from&callerIdName=$from&event=AgiEvent&type=SIP&uniqueId=1481543422.1968&StartTime=$now&callUUID=$uuid&callstatus=StartApp' http://$host/vtigercrm/modules/PBXManager/callbacks/PBXManager.php";
	warn "Send Event: $json\n";
	$mq->publish(1, "incoming", $json);
	#warn $cmd;
	#system($cmd);
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


sub monitor_callback() {
	require $default_include;
	$app{callback_timeout} ||= 5;
	while (1) {
		$sql = "select channel_uuid,other_channel_uuid,hold_timestamp,ext,domain_name from v_hold where now()- interval '$app{callback_timeout} S' >= hold_timestamp"; 
		warn "sql: $sql!\n";
		%callback = &database_select_as_hash($sql, "other_channel_uuid,hold_timestamp,ext,domain_name");
		
		for $uuid (keys %callback) {
			$cmd = "uuid_transfer $uuid $callback{$uuid}{ext} XML $callback{$uuid}{domain_name}";
			warn "cmd: $cmd!\n";
			$res = `fs_cli -rx "$cmd"`;
			
			warn $res;
			
			&database_do("delete from v_hold where channel_uuid='$uuid'");
		}
		sleep 3;
	}
	
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

sub asterisk_debug_print(){
	local($msg) = @_;
	print STDERR "$msg \n";
	
}
#======================================================
 
sub reaper {
   while ((my $child = waitpid(-1, WNOHANG)) > 0) {
	   warn "process $child exit ...\n";
   }
}

sub out() {
    local $str = shift;
    print "[", &now(), "] ", $str, "\n";
}

sub now() {
    @v = localtime;
    return sprintf("%04d-%02d-%02d %02d:%02d:%02d", 1900+$v[5],$v[4]+1,$v[3],$v[2],$v[1],$v[0]);
}

sub _stop_server {
    &out("** catch INT SIGNAL, server will quit!");
    exit 0;
}


sub _die {
    &out("DIE: pid=$$ and cause= @_");
    &_exit("quit with die");
}

sub _warn {
    &out("WARN: pid=$$ and cause=@_");
}

