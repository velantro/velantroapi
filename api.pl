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

my $HOSTNAME = 'vconnect.velantro.net';
my $HOSTIP   = '67.215.227.218';

my $VCONNECT_SERVERS = "('67.215.243.242','67.215.243.122')";
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
$query_string = uri_unescape($cgi->query_string());
for (split /&|&&/, $query_string) {
	warn $_;
	($var, $val) = split '=', $_, 2;
	$query{$var} = $val;
	
	warn "$var ==> $val";
}
if ($query{msgid}) {
	$query{action} = 'savesms';
}

my $ua  = LWP::UserAgent->new('agent' => "Mozilla/5.0 (Windows; U; Windows NT 5.1; zh-CN; rv:1.9.2.13) Gecko/20101203 Firefox/3.6.13 GTB7.1");
my $jar = HTTP::Cookies->new(
    file => "/tmp/cookie.txt",
    autosave => 1,
);
if ($query{action} eq 'getincomingevent') {
	print $cgi->header(-type  =>  'text/event-stream;charset=UTF-8', '-cache-control' => 'NO-CACHE', );
} else {
	print $cgi->header();
	
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



my ($api_login, $api_pass);

my $txt = `cat /etc/vconnect.conf`;
my %config = ();
for (split /\n/, $txt) {
	my ($key, $val)	= split /=/, $_, 2;
	
	if ($key) {
		$config{$key} = $val;
		warn "$key=$val\n";
	}
}

$adb = $config{dbname} if $config{dbname};
$ahost = $config{dbhost} if $config{dbhost};
$auser = $config{dbuser} if $config{dbuser};
$apass = $config{dbpass} if $config{dbpass};

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

if ($query{action} eq 'addwidget') {
    add_widget();
} elsif ($query{action} eq 'updatewidget') {
    update_widget();
} elsif ($query{action} eq 'deletewidget') {
    delete_widget();
} elsif ($query{action} eq 'addblacklist') {
    add_blacklist();
} elsif ($query{action} eq 'removeblacklist') {
    remove_blacklist();
} elsif ($query{action} eq 'getcallhistory') {
	get_callhistory();
} elsif ($query{action} eq 'getvoicemail') {
	get_voicemail();
} elsif ($query{action} eq 'updateworktime') {
	update_worktime();
} elsif ($query{action} eq 'getpiwikwidgeturl') {
		get_piwikwidgeturl();
} elsif ($query{action} eq 'checkip') {
	check_ip();
} elsif ($query{action} eq 'getdid') {
	get_did();
} elsif ($query{action} eq 'gettollfreedid') {
	get_tollfreedid();
} elsif ($query{action} eq 'savesms') {
	save_sms();
} elsif ($query{action} eq 'enablesms') {
	enable_sms();
} elsif ($query{action} eq 'getsmshistory') {
	get_smshistory();
} elsif ($query{action} eq 'setrecording') {
	set_recording();
} elsif ($query{action} eq 'getregister') {
	get_register();
} elsif ($query{action} eq 'getsummary') {
	get_summary();
} elsif ($query{action} eq 'getrealtimesummary') {
	get_realtimesummary();
} elsif ($query{action} eq 'updatevoicemail') {
	update_voicemail();
} elsif ($query{action} eq 'updatevoicemailgreeting') {
	update_voicemailgreeting();
} elsif ($query{action} eq 'removevoicemailgreeting') {
	remove_voicemailgreeting();
} elsif ($query{action} eq 'updateringtimeout') {
	update_ringtimeout();
} elsif ($query{action} eq 'deletevoicemail') {
	delete_voicemail();
}  elsif ($query{action} eq 'getdirectdid' or $query{action} eq 'getdirectdialdid') {
	get_directdialdid();
} elsif ($query{action} eq 'adddirectdid') {
	add_directdid();
} elsif ($query{action} eq 'getdashboard') {
	get_dashboard();
} elsif ($query{action} eq 'updaterecordingstorage') {
	update_recordingstorage();
} elsif ($query{action} eq 'updateliveusage') {
	update_usage();
} elsif ($query{action} eq 'updatechannels') {
	update_channels();
} elsif ($query{action} eq 'updateemail') {
	update_email();
} elsif ($query{action} eq 'addwidgetdid') {
	add_widgetdid();
} elsif ($query{action} eq 'addcallback') {
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
} elsif ($query{action} eq 'addblacknumber') {
	add_blacknumber();
} elsif ($query{action} eq 'deleteblacknumber') {
	delete_blacknumber();
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
} elsif ($query{action} eq 'updateaws'){
	do_aws();
} else {
     print j({error => '1', 'message' => 'undefined action', 'actionid' => $query{actionid}});
    exit 0;
}

sub add_widget {
    my $sth = $dbh->prepare("select extension_uuid extension_uid,extension from v_extensions where extension_uuid not in (select extension_uid from vconnect_widget) and domain_uuid='9c060822-026a-492d-bb08-8a88a6249631' order by extension limit 1");
    $sth   -> execute();
    
    my $row = $sth->fetchrow_hashref();
    if (!$row->{extension_uid}) {
        print j({error => '1', 'message' => 'internal error: no available ext', 'actionid' => $query{actionid}});
        exit 0;
    }
	
	my $widget_id = '';
    if ($query{widgetid}) {
		$widget_id = $query{widgetid};

		$sth = $dbh->prepare("insert into vconnect_widget(widgetid,extension_uid) values (?,?)")->execute($widget_id, $row->{extension_uid});
	} else {
		$sth = $dbh->prepare("insert into vconnect_widget(extension_uid) values (?)")->execute($row->{extension_uid});
		
		$sth = $dbh->prepare("select widgetid from vconnect_widget where extension_uid=?");
		$sth -> execute($row->{extension_uid});
		
		my $r = $sth->fetchrow_hashref;
		#$widget_id = $dbh->last_insert_id(undef, undef, 'vconnect_widget', 'widgetid');
		$widget_id = $r->{widgetid};
	}
    
    #http://$HOSTNAME/app/calls/call_edit.php?id=c0acfed5-2878-4302-8b9f-5366809911ac&a=call_forward

    _update_forward($row->{extension_uid}, $query{numbers});
	_update_password($row->{extension_uid},'BEvzUSv..2');

	my $piwiksiteid = _add_piwik_site($row->{extension});
	
	
	$dbh->prepare("update vconnect_widget set piwiksiteid=? where widgetid=?")
		  ->execute($piwiksiteid, $widget_id);
			  
    print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid},'widgetid' => $widget_id, piwiksiteid => $piwiksiteid,
    				'extension' => $row->{extension}});
}


sub update_widget {
	if (!$query{widgetid}) {
		my $sth = $dbh->prepare("select extension_uuid extension_uid,extension from v_extensions where extension_uuid not in (select extension_uid from vconnect_widget) and domain_uuid='9c060822-026a-492d-bb08-8a88a6249631' order by extension limit 1");
		$sth   -> execute();
    
		my $row = $sth->fetchrow_hashref();
		if (!$row->{extension_uid}) {
			print j({error => '1', 'message' => 'internal error: no available ext', 'actionid' => $query{actionid}});
			exit 0;
		}
		
		my $widget_id = '';
 
		$sth = $dbh->prepare("insert into vconnect_widget(extension_uid) values (?)")->execute($row->{extension_uid});
		
		#$query{widgetid} = $dbh->last_insert_id(undef, undef, 'vconnect_widget', 'widgetid');
		$sth = $dbh->prepare("select widgetid from vconnect_widget where extension_uid=?");
		$sth -> execute($row->{extension_uid});
		
		my $r = $sth->fetchrow_hashref;
		#$widget_id = $dbh->last_insert_id(undef, undef, 'vconnect_widget', 'widgetid');
		$query{widgetid} = $r->{widgetid};
			
	}
	
    my $sth = $dbh->prepare("select extension_uid,did from vconnect_widget where widgetid=?");
    $sth   -> execute($query{widgetid});
    
    my $row = $sth->fetchrow_hashref();
    if (!$row->{extension_uid}) {
    
		my $sth = $dbh->prepare("select extension_uuid extension_uid,extension from v_extensions where extension_uuid not in (select extension_uid from vconnect_widget) and domain_uuid='9c060822-026a-492d-bb08-8a88a6249631' order by extension limit 1");
		$sth   -> execute();
		
		my $row = $sth->fetchrow_hashref();
		if (!$row->{extension_uid}) {
			print j({error => '1', 'message' => 'internal error: no available ext', 'actionid' => $query{actionid}});
			exit 0;
		} else {
			$widget_id = $query{widgetid};

			$sth = $dbh->prepare("insert into vconnect_widget(widgetid,extension_uid) values (?,?)")
					  ->execute($widget_id, $row->{extension_uid});
		}
	}
    
	if ($query{channels}) {
		$dbh->prepare("update vconnect_widget set channels=$query{channels} where widgetid=?")->execute($query{widgetid});
	}
	
    _update_forward($row->{extension_uid}, $query{numbers});
	_update_did($row->{did}, $query{numbers}) if $row->{did};
    print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid},'widgetid' => $query{widgetid}});
}

sub update_channels {
	my $ids = $query{widgetid};
	if (!$ids) {
        print j({error => '1', 'message' => 'widgetids is null', 'actionid' => $query{actionid}});
        exit 0;
    }
	
	my $sql = "update vconnect_widget set channels=? where widgetid IN ($ids)";
	my $sth = $dbh->prepare($sql);
	$sth   -> execute($query{channels});
	
    print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid},'widgetid' => $query{widgetid}});
}

sub update_email {
	my $ids = $query{widgetid};
	if (!$ids) {
        print j({error => '1', 'message' => 'widgetids is null', 'actionid' => $query{actionid}});
        exit 0;
    }
	
	my $sql = "update vconnect_widget set email=? where widgetid IN ($ids)";
	my $sth = $dbh->prepare($sql);
	$sth   -> execute($query{email});
	
    print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid},'widgetid' => $query{widgetid}});
}

sub delete_widget {
    if (!$query{widgetid}) {
        print j({error => '1', 'message' => 'widgetid is null', 'actionid' => $query{actionid}});
        exit 0;
    }
    
	my $sql = "select extension_uid,extension,widgetid,did,tollfreedid,user_context from v_extensions,vconnect_widget where v_extensions.extension_uuid=vconnect_widget.extension_uid and (widgetid='$query{widgetid}')" ;
   # my $sth = $dbh->prepare("select extension_uid,did,tollfreedid from vconnect_widget where widgetid=?");
	my $sth  = $dbh->prepare($sql);
	$sth   -> execute();
    
    my $row = $sth->fetchrow_hashref();
    if (!$row->{extension_uid}) {
        print j({error => '1', 'message' => 'internal error: no available ext', 'actionid' => $query{actionid}});
        exit 0;
    }
    
    $sth = $dbh->prepare("delete from vconnect_widget where widgetid=?");
    $sth   -> execute($query{widgetid});
    _update_password($row->{extension_uid});
    _shutdown_forward($row->{extension_uid});
	_remove_did($row->{did}) if $row->{did};
	_remove_did($row->{tollfreedid}) if $row->{tollfreedid};
	
	
	my %month  = ('01' => 'Jan', '02' => 'Feb', '03' => 'Mar', '04' => 'Apr', '05' => 'May', '06' => 'Jun', '07' => 'Jul', '08' => 'Aug',
              '09' => 'Sep', '10' => 'Oct', '11' => 'Nov', '12' => 'Dec');
	my $dest_base = '/usr/local/freeswitch';
	
	#$dbh->prepare("delete from v_xml_cdr where extension_uuid=?")->execute($row->{extension_uid});
	$sth = $dbh->prepare("select uuid,start_stamp from v_xml_cdr where extension_uuid=?");
	$sth -> execute($row->{extension_uid});	
	
	while ($r = $sth->fetchrow_hashref) {
		my ($y,$M, $d, $h, $m, $s) = $r->{start_stamp} =~ /(\d\d\d\d)\-(\d\d)\-(\d\d) (\d\d):(\d\d):(\d\d)/;
        my $recordingfile  = "$dest_base/recordings/$row->{user_context}/$y/$month{$M}/$d/$r->{uuid}.wav";
        #my $dest_name = "$y$M$d" . "_$h$m$s" . "_$row->{caller_id_number}_$row->{destination_number}_$row->{uuid}.wav";
        warn "remove recordingfile: $recordingfile\n";
		unlink $recordingfile;
		
		$dbh->prepare("delete from v_voicemail_messages where voicemail_message_uuid=?")->execute($row->{uuid});
	}
	
	unlink glob "$dest_base/storage/voicemail/default/$row->{user_context}/$row->{extension}/*";
	
	$dbh->prepare("delete from v_xml_cdr where extension_uuid=?")->execute($row->{extension_uid});
	
    print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}});

}

sub add_blacklist {
    my $sth = $dbh->prepare("insert into widget_blacklist (widgetid,ip) values (?, ?)");
    for (split ',', $query{ips}) {
        $sth->execute($query{widgetid}, $_);
    }
    
    print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}});
}

sub remove_blacklist {
    my $sth = $dbh->prepare("delete from widget_blacklist where widgetid=? and ip=?");
    for (split ',', $query{ips}) {
        $sth->execute($query{widgetid}, $_);
    }
    
    print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}});
}

sub add_blacknumber {
    my $sth = $dbh->prepare("insert into widget_blacknumber (widgetid,number) values (?, ?)");
    for (split ',', $query{number}) {
        $sth->execute($query{widgetid}, $_);
    }
    
    print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}});
}

sub delete_blacknumber {
    my $sth = $dbh->prepare("delete from widget_blacknumber where widgetid=? and number=?");
    for (split ',', $query{number}) {
        $sth->execute($query{widgetid}, $_);
    }
    
    print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}});
}
sub get_callhistory {
	if (!$query{widgetid}) {		
		print j({error => '0', 'message' => 'ok: no widgetid define', 'actionid' => $query{actionid}});
		exit 0;
	}
	
	my $sql = "select extension,widgetid from v_extensions,vconnect_widget where v_extensions.extension_uuid=vconnect_widget.extension_uid and widgetid='$query{widgetid}'" ;
	#warn $sql;
	my $sth = $dbh->prepare($sql);	
	$sth->execute();
	
	my %exten_numbers = ();
	my $extension     = '';
	while (my $row = $sth->fetchrow_hashref) {
		$extension = $row->{extension};
	}
	
	if ($extension) {
	    if ($query{localdid}) {
			$query{localdid} = join ',', map {"'$_'"} split ',', $query{localdid};
		}
		if ($query{tollfreedid}) {
			$query{tollfreedid} = join ',', map {"'$_'"} split ',', $query{tollfreedid};			
		}
		$sql = "select v_xml_cdr.*,v_visitorid.visitorid from v_xml_cdr left join v_visitorid on v_xml_cdr.uuid=v_visitorid.uuid " .
			  "where destination_number not like 'conference%' and (caller_id_number='$extension'" .
			" OR caller_id_name='callback-$extension'" . ($query{localdid} ? " OR fromdid in ($query{localdid}) " : "") .
			  ($query{tollfreedid} ? " OR fromdid in ($query{tollfreedid}) " : "") . ") and  hangup_cause <> 'ORIGINATOR_CANCEL'";
	
	
			#. " and  remote_media_ip in $VCONNECT_SERVERS and hangup_cause <> 'ORIGINATOR_CANCEL'";
	
		warn $sql;
		if ($query{startday}) {
			$startday = $query{startday};
			$startday =~ s/\+/ /g;
			
			$sql .= " AND start_stamp > '$startday' ";
		}
		
		if ($query{endday}) {
			$endday = $query{endday};
			$endday =~ s/\+/ /g;
			$sql .= " AND start_stamp < '$endday'";
		}
		
		$sql .= " Order by start_stamp desc";
		warn $sql;
		
		$sth = $dbh->prepare($sql);
		$sth->execute();
		
		my $items = [];
		while (my $r = $sth->fetchrow_hashref) {
			my ($y, $m, $d) = $r->{start_stamp} =~ /(\d{4})\-(\d{2})\-(\d{2})/;
			$m							= $month{$m};
			my $recording   = '';
			if (-e "$recordings_dir/$HOSTNAME/archive/$y/$m/$d/$r->{uuid}.wav") {
				$recording    = "/recordings/$HOSTNAME/archive/$y/$m/$d/$r->{uuid}.wav";
			}
			
			if (length($r->{caller_id_name}) < 8) {
				$r->{caller_id_name} = $r->{remote_media_ip};
			}
		
			push @$items, {callstatus => $r->{hangup_cause}, date => $r->{start_stamp}, number => $r->{'destination_number'},
				   duration => $r->{billsec},cost => 0.01*($r->{billsec}/60 + $r->{billsec}%60 ?1:0),
				   widgetid=>$exten_numbers{$r->{caller_id_number}}, url=>$r->{caller_id_name},
				   country => get_country($r->{caller_id_name}), recordurl => $recording, 'tonumber' => $r->{fromdid},
				   'type' => _get_number_type($r->{fromdid}),uuid=>$r->{uuid},visitorid => $r->{visitorid}};

			
		}
					print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid},'items' => $items});

	} else {
		print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid},'items' => []});
	}
		
}

sub _get_number_type {
	my $number = shift;
	if (length($number) < 10) {
		return 0;
		#code
	}
	my $npa = substr($number, 0, 3);
	if ($npa eq '800' || $npa eq '811' || $npa eq '822'|| $npa eq '833'|| $npa eq '844'|| $npa eq '855'
	    || $npa eq '866'|| $npa eq '877'|| $npa eq '888'|| $npa eq '899') {
		
		return 2;
		#code
	} else {
		return 1;
	}	
}

sub get_voicemail {
	my $items = [];
	my $widgetid = $query{widgetid};
	if (!$widgetid) {		
		print j({error => '0', 'message' => 'ok: no widgetid define', 'actionid' => $query{actionid}});
		exit 0;
	}
	my $sql   = "select voicemail_message_uuid,extension,from_unixtime(created_epoch) date,
	v_voicemail_messages.caller_id_name caller_id_name,v_voicemail_messages.caller_id_number caller_id_number,message_length,remote_media_ip
	from v_voicemail_messages,v_voicemails,v_extensions,vconnect_widget,v_xml_cdr
	where v_voicemail_messages.voicemail_uuid=v_voicemails.voicemail_uuid and v_voicemails.voicemail_id and
	v_voicemails.voicemail_id=v_extensions.extension and v_extensions.extension_uuid=vconnect_widget.extension_uid and
	v_voicemail_messages.voicemail_message_uuid=v_xml_cdr.uuid and widgetid=?";
	
	if ($query{startday}) {
		$sql .= " AND created_epoch > '" . str2time($query{startday}) . "'" ;
	}
	
	if ($query{endday}) {
		$sql .= " AND created_epoch > '" . str2time($query{endday}) . "'" ;
	}
	
	my $sth   = $dbh->prepare($sql);
	$sth     -> execute($widgetid);
	my @items = ();
	while (my $row = $sth->fetchrow_hashref) {
		$row->{caller_id_name} = $row->{remote_media_ip};

		push @items, {date => $row->{date}, name => $row->{caller_id_name}, number => $row->{caller_id_number},
									duration => $row->{message_length}, uuid => $row->{voicemail_message_uuid},
									vmurl => "/voicemail/default/$HOSTNAME/$row->{extension}/msg_$row->{voicemail_message_uuid}.wav"
								};
	}
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid},'items' => \@items}); 
}

sub update_worktime {
	my $widgetid = $query{widgetid};
	if (!$widgetid) {		
		print j({error => '0', 'message' => 'ok: no widgetid define', 'actionid' => $query{actionid}});
		exit 0;
	}
	
	my $timespan = $query{timespan} || $query{time};
	if ($timespan) {
		my $sth = $dbh->prepare("update vconnect_widget set timespan=? where widgetid=?");
		$sth   -> execute($timespan, $widgetid);
		
	}
	
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}});
}

sub get_summary {
	my $count = $query{count} || 1;
	my $unit  = $query{unit}  || 'day';
	my ($voipcalls, $voipcallsminute, $localcalls, $localcallsminute, $tollfreecalls, $tollfreecallsminute, $totalwidgets) = (0, 0, 0, 0, 0, 0, 0);
	my $sth   = $dbh->prepare("select billsec,fromdid from v_xml_cdr where start_stamp > date_sub(now(), interval $count $unit) and fromdid is not null and fromdid !=''");
	$sth	 -> execute();
	
	while (my $row = $sth->fetchrow_hashref) {
		my $type = _get_number_type($row->{fromdid});
		if ($type == 1) {
			$localcalls++;
			$localcallsminute += $row->{billsec};
		} elsif ($type == 2) {
			$tollfreecalls++;
			$tollfreecallsminute += $row->{billsec};
		} else {
			$voipcalls++;
			$voipcallsminute += $row->{billsec};
		}		
	}
	
	$sth   = $dbh->prepare("select * from vconnect_widget where createdate > date_sub(now(), interval $count $unit)");
	$sth   -> execute();
	
	while (my $row = $sth->fetchrow_hashref) {
		$totalwidgets++;
	}
	
	
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}, 'voipcalls' => $voipcalls, 'voipcallsminute' => $voipcallsminute / 60,'localcalls' => $localcalls,
		'localcallsminute' => $localcallsminute /60 , 'tollfreecalls' => $tollfreecalls, 'tollfreecallsminute' => $tollfreecallsminute /60, 'totalwidgets' => $totalwidgets});

	
}

sub get_realtimesummary {	
	my $ru = int rand(99);
	my $au = int rand(99);
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}, realtimeusers => $ru, 'activeusers' => $au});
	
}

sub get_piwikwidgeturl {
	my $widgetid = $query{widgetid};
	if (!$widgetid) {		
		print j({error => '1', 'message' => 'error: no widgetid define', 'actionid' => $query{actionid}});
		exit 0;
	}
	
	my $url = '';
	
	my $sth = $dbh->prepare("select piwiksiteid from vconnect_widget where widgetid=?");
	$sth   -> execute($widgetid);
	my $row = $sth->fetchrow_hashref;
	my $piwiksiteid = $row->{piwiksiteid};
	
	if (!$piwiksiteid) {
			print j({error => '1', 'message' => 'error: no piwik site define', 'actionid' => $query{actionid}});
			exit 0;
	}
	
	if (!$form{type} || $form{type} eq 'default') {
		$url  = "http://$HOSTNAME/analytics/index.php?module=Widgetize&action=iframe&columns[]=nb_visits&widget=1&". 
		"moduleToWidgetize=VisitsSummary&actionToWidgetize=getEvolutionGraph&idSite=$piwiksiteid&period=day&date=today&disableLink=1&widget=1";
		
	}
	
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid},'url' => $url}); 

}

sub delete_voicemail {
	my $uuid = $query{uuid};
	if (!$uuid) {		
		print j({error => '1', 'message' => 'error: no uuid define', 'actionid' => $query{actionid}});
		exit 0;
	}
	
	my $sql   = "select voicemail_message_uuid,extension,from_unixtime(created_epoch) date,caller_id_name,caller_id_number,
	message_length from v_voicemail_messages,v_voicemails,v_extensions,vconnect_widget 
	where v_voicemail_messages.voicemail_uuid=v_voicemails.voicemail_uuid and v_voicemails.voicemail_id and
	v_voicemails.voicemail_id=v_extensions.extension and v_extensions.extension_uuid=vconnect_widget.extension_uid and voicemail_message_uuid=?";
	
	my $sth = $dbh->prepare($sql);
	$sth   -> execute($uuid);
	my $row = $sth->fetchrow_hashref;
	
	unlink "/usr/local/freeswitch/storage/voicemail/default/$HOSTNAME/$row->{extension}/msg_$row->{voicemail_message_uuid}.wav";
	$dbh->prepare("delete from v_voicemail_messages where voicemail_message_uuid=?")
		->execute($uuid);
		
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}}); 
}

sub update_ringtimeout {
	my $widgetid = $query{widgetid};
	if (!$widgetid) {		
		print j({error => '1', 'message' => 'error: no widgetid define', 'actionid' => $query{actionid}});
		exit 0;
	}
	
	my $timeout = $query{rings} * 3 || 30;
	$dbh->prepare("update vconnect_widget set ringtimeout=? where widgetid=?")
		->execute($timeout, $widgetid);
	
	
	my $sql = "select extension,widgetid,extension_uid from v_extensions,vconnect_widget where v_extensions.extension_uuid=vconnect_widget.extension_uid and widgetid=?" ;
	warn $sql;
	my $sth = $dbh->prepare($sql);	
	$sth->execute($widgetid);
	my $row = $sth->fetchrow_hashref;
	
    my $url = "http://$HOSTNAME/app/calls/call_edit.php?id=$row->{extension_uid}&a=call_forward";
	my $socketurl = "http://$HOSTNAME/app/exec/exec.php";

	$ua->request(POST $socketurl, ["switch_cmd" => "db insert/vconnect_ringtimeout/$row->{extension}/$timeout", 'submit' => 'Execute']);

	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}}); 
}

sub _update_forward {
    my ($extension_uid, $numbers) = @_;
	my $dsttype   = $query{dsttype} || 1;
	my $socketurl = "http://$HOSTNAME/app/exec/exec.php";
	my $dstnumber = $numbers;
	if ($dsttype != 1) {
		$numbers = '';
	}
	

    my $url = "http://$HOSTNAME/app/calls/call_edit.php?id=$extension_uid&a=call_forward";
	warn "set forward number: $extension_uid ==> $numbers";
    $ua->request(POST $url,
                    ["forward_all_enabled" => "true", "forward_all_destination" => $numbers,
                     "follow_me_enabled" => "false", "dnd_enabled" => "false", "submit" => "Save"]
                );
	
	
	my $sth = $dbh->prepare("select * from v_extensions where extension_uuid=?");
	$sth   -> execute($extension_uid);
	my $row = $sth->fetchrow_hashref();
	
	
	$ua->request(POST $socketurl, ["switch_cmd" => "db insert/vconnect_dsttype/$row->{extension}/$dsttype", 'submit' => 'Execute']);

	$ua->request(POST $socketurl, ["switch_cmd" => "db insert /vconnect/$row->{extension}/$dstnumber", 'submit' => 'Execute']);	
	
	
}

sub _update_voicemail {
		#_update_voicemail($row->{extension_uuid}, $mailto, $attachfile, $keeplocal, $enable);

	my ($extension_uuid, $extension, $password, $mailto, $attachfile, $keeplocal, $enable, $recording) = @_;	
		

    my $url = "http://$HOSTNAME/app/extensions/extension_edit.php?id=$extension_uuid";
	warn "set voicemail address: $extension [$extension_uuid] ==> $mailto";
	
	#&vm_attach_file=&vm_keep_local_after_email=&toll_allow=&call_timeout=30&call_group=&hold_music=&user_context=vconnect.velantro.net&auth_acl=&cidr=&sip_force_contact=&sip_force_expires=&nibble_account=&mwi_account=&sip_bypass_media=&dial_string=&enabled=true&description=&extension_uuid=c0acfed5-2878-4302-8b9f-5366809911ac&submit=Save
	
    my $res = $ua->request(POST $url,
                ["extension" => $extension, "password" => $password, 'vm_enabled' => $enable, "vm_mailto" => $mailto, "extension_uuid" => $extension_uuid, "id" => $extension_uuid, 'enabled' => 'true', 'directory_visible' => 'true', 'directory_exten_visible' => 'true',  'user_context' => $HOSTNAME, 'recording' => $recording]);
	#print $res->content;
	$url = "http://$HOSTNAME/app/extensions/extensions.php";
	$ua->request(POST $url, ["abc" => 1]);
}

sub _shutdown_forward {
    my ($extension_uid, $numbers) = @_;
    my $url = "http://$HOSTNAME/app/calls/call_edit.php?id=$extension_uid&a=call_forward";
    $ua->request(POST $url,
                    ["forward_all_enabled" => "false", "forward_all_destination" => '',
                     "follow_me_enabled" => "false", "dnd_enabled" => "false", "submit" => "Save"]
                );
	my $sth = $dbh->prepare("select * from v_extensions where extension_uuid=?");
	$sth   -> execute($extension_uid);
	my $row = $sth->fetchrow_hashref();
	
	$url = "http://$HOSTNAME/app/exec/exec.php";
	$ua->request(POST $url, ["switch_cmd" => "db delete /vconnect/$row->{extension}", 'submit' => 'Execute']);
}

sub _update_password {
	my ($extension_uid, $password) = @_;
	my $sth = $dbh->prepare("select * from v_extensions where extension_uuid=?");
	$sth   -> execute($extension_uid);
	my $row = $sth->fetchrow_hashref();
	#$query  = "submit=Save&extension=100000&number_alias=&password=BEvzUSv..2&user_uuid=&vm_password=user-choose&accountcode=&effective_caller_id_name=&effective_caller_id_number=&outbound_caller_id_name=&outbound_caller_id_number=&emergency_caller_id_number=&directory_full_name=&directory_visible=true&directory_exten_visible=true&limit_max=5&limit_destination=&device_uuid=&device_line=&vm_enabled=true&vm_mailto=&vm_attach_file=&vm_keep_local_after_email=&toll_allow=&call_timeout=30&call_group=&hold_music=&user_context=$HOSTNAME&auth_acl=&cidr=&sip_force_contact=&sip_force_expires=&nibble_account=&mwi_account=&sip_bypass_media=&dial_string=%7Bpresence_id%3D8184885588%40$HOSTNAME%2Cinstant_ringback%3Dtrue%7Dloopback%2F8184885588&enabled=true&description=&extension_uuid=c0acfed5-2878-4302-8b9f-5366809911ac";
	my %query = ();
	for (keys %$row) {
		$query{$_} = $row->{$_};
	}
	
	$query{submit} = 'Save';
	$query{password} = $password;
		
	my $url = "http://$HOSTNAME/app/extensions/extension_edit.php?id=$extension_uid";
	$ua->request(POST $url, [%query]);
}

sub _add_piwik_site {
	my $extension = shift || return;
	my $siteurl   = "http://webcall.velantro.net/vconnect/free/?" . encode_base64("tenant=vconnect&&ext=$extension"); #dGVuYW50PXZjb25uZWN0JmV4dD0xMDAxMDA=
	warn $siteurl;
	
	my $apiurl    = "http://$HOSTNAME/analytics/?module=API&method=SitesManager.addSite&format=xml&&token_auth=b2d447fcf7c4bf9c0d62b99c6f069226&&" .
								  "siteName=$extension&&urls=$siteurl";
								  
  my $result	 = get $apiurl;
  warn $result;
  return getvalue('result', $result);

}


sub _delete_piwik_site {
	my $siteid = shift || return;
	my $apiurl = "http://$HOSTNAME/analytics/?module=API&method=SitesManager.addSite&format=xml&&token_auth=b2d447fcf7c4bf9c0d62b99c6f069226&&" .
							 "idSite=$siteid";
	get $apiurl;								  
}

sub j {
    return encode_json(shift);
}

sub get_country {
	my $ip = shift || return '';
	my $sth = $dbh->prepare("select country from v_ip where ip=?");
	$sth   -> execute($ip);
	my $row = $sth->fetchrow_hashref();
	
	my $country = $row->{country};
	
	if (!$country) {
		if ($ip =~ /\./) {		
			($country) = `whois $ip | grep -i 'Country:'` =~ /Country:\s+(.+)$/i;
		} else {
			$country   = _get_country_by_phonenumber($ip);
		}
		
		if ($country) {
			$dbh->prepare("insert into v_ip (ip,country) values (?, ?)")->execute($ip, lc $country);
		}
	}
	
	return $country;
}

sub _get_country_by_phonenumber {
	my $number = shift;
	%C = (
	'244' => [ 'AO', 'Angola','-7'],
	'93' => [ 'AF', 'Afghanistan','0'],
	'355' => [ 'AL', 'Albania','-7'],
	'213' => [ 'DZ', 'Algeria','-8'],
	'376' => [ 'AD', 'Andorra','-8'],
	'1264' => [ 'AI', 'Anguilla','-12'],
	'1268' => [ 'AG', 'Antigua and Barbuda','-12'],
	'54' => [ 'AR', 'Argentina','-11'],
	'374' => [ 'AM', 'Armenia','-6'],
	'247' => [ '', 'Ascension','-8'],
	'61' => [ 'AU', 'Australia','2'],
	'43' => [ 'AT', 'Austria','-7'],
	'994' => [ 'AZ', 'Azerbaijan','-5'],
	'1242' => [ 'BS', 'Bahamas','-13'],
	'973' => [ 'BH', 'Bahrain','-5'],
	'880' => [ 'BD', 'Bangladesh','-2'],
	'1246' => [ 'BB', 'Barbados','-12'],
	'375' => [ 'BY', 'Belarus','-6'],
	'32' => [ 'BE', 'Belgium','-7'],
	'501' => [ 'BZ', 'Belize','-14'],
	'229' => [ 'BJ', 'Benin','-7'],
	'1441' => [ 'BM', 'Bermuda Is.','-12'],
	'591' => [ 'BO', 'Bolivia','-12'],
	'267' => [ 'BW', 'Botswana','-6'],
	'55' => [ 'BR', 'Brazil','-11'],
	'673' => [ 'BN', 'Brunei','0'],
	'359' => [ 'BG', 'Bulgaria','-6'],
	'226' => [ 'BF', 'Burkina-faso','-8'],
	'95' => [ 'MM', 'Burma','-1.3'],
	'257' => [ 'BI', 'Burundi','-6'],
	'237' => [ 'CM', 'Cameroon','-7'],
	'1' => [ 'CA', 'Canada','-13'],
	'1345' => [ '', 'Cayman Is.','-13'],
	'236' => [ 'CF', 'Central African Republic','-7'],
	'235' => [ 'TD', 'Chad','-7'],
	'56' => [ 'CL', 'Chile','-13'],
	'86' => [ 'CN', 'China','0'],
	'57' => [ 'CO', 'Colombia','0'],
	'242' => [ 'CG', 'Congo','-7'],
	'682' => [ 'CK', 'Cook Is.','-18.3'],
	'506' => [ 'CR', 'Costa Rica','-14'],
	'53' => [ 'CU', 'Cuba','-13'],
	'357' => [ 'CY', 'Cyprus','-6'],
	'420' => [ 'CZ', 'Czech Republic','-7'],
	'45' => [ 'DK', 'Denmark','-7'],
	'253' => [ 'DJ', 'Djibouti','-5'],
	'1890' => [ 'DO', 'Dominica Rep.','-13'],
	'593' => [ 'EC', 'Ecuador','-13'],
	'20' => [ 'EG', 'Egypt','-6'],
	'503' => [ 'SV', 'EI Salvador','-14'],
	'372' => [ 'EE', 'Estonia','-5'],
	'251' => [ 'ET', 'Ethiopia','-5'],
	'679' => [ 'FJ', 'Fiji','4'],
	'358' => [ 'FI', 'Finland','-6'],
	'33' => [ 'FR', 'France','-8'],
	'594' => [ 'GF', 'French Guiana','-12'],
	'241' => [ 'GA', 'Gabon','-7'],
	'220' => [ 'GM', 'Gambia','-8'],
	'995' => [ 'GE', 'Georgia','0'],
	'49' => [ 'DE', 'Germany','-7'],
	'233' => [ 'GH', 'Ghana','-8'],
	'350' => [ 'GI', 'Gibraltar','-8'],
	'30' => [ 'GR', 'Greece','-6'],
	'1809' => [ 'GD', 'Grenada','-14'],
	'1671' => [ 'GU', 'Guam','2'],
	'502' => [ 'GT', 'Guatemala','-14'],
	'224' => [ 'GN', 'Guinea','-8'],
	'592' => [ 'GY', 'Guyana','-11'],
	'509' => [ 'HT', 'Haiti','-13'],
	'504' => [ 'HN', 'Honduras','-14'],
	'852' => [ 'HK', 'Hongkong','0'],
	'36' => [ 'HU', 'Hungary','-7'],
	'354' => [ 'IS', 'Iceland','-9'],
	'91' => [ 'IN', 'India','-2.3'],
	'62' => [ 'ID', 'Indonesia','-0.3'],
	'98' => [ 'IR', 'Iran','-4.3'],
	'964' => [ 'IQ', 'Iraq','-5'],
	'353' => [ 'IE', 'Ireland','-4.3'],
	'972' => [ 'IL', 'Israel','-6'],
	'39' => [ 'IT', 'Italy','-7'],
	'225' => [ '', 'Ivory Coast','-6'],
	'1876' => [ 'JM', 'Jamaica','-12'],
	'81' => [ 'JP', 'Japan','1'],
	'962' => [ 'JO', 'Jordan','-6'],
	'855' => [ 'KH', 'Kampuchea (Cambodia )','-1'],
	'327' => [ 'KZ', 'Kazakstan','-5'],
	'254' => [ 'KE', 'Kenya','-5'],
	'82' => [ 'KR', 'Korea','1'],
	'965' => [ 'KW', 'Kuwait','-5'],
	'331' => [ 'KG', 'Kyrgyzstan','-5'],
	'856' => [ 'LA', 'Laos','-1'],
	'371' => [ 'LV', 'Latvia','-5'],
	'961' => [ 'LB', 'Lebanon','-6'],
	'266' => [ 'LS', 'Lesotho','-6'],
	'231' => [ 'LR', 'Liberia','-8'],
	'218' => [ 'LY', 'Libya','-6'],
	'423' => [ 'LI', 'Liechtenstein','-7'],
	'370' => [ 'LT', 'Lithuania','-5'],
	'352' => [ 'LU', 'Luxembourg','-7'],
	'853' => [ 'MO', 'Macao','0'],
	'261' => [ 'MG', 'Madagascar','-5'],
	'265' => [ 'MW', 'Malawi','-6'],
	'60' => [ 'MY', 'Malaysia','-0.5'],
	'960' => [ 'MV', 'Maldives','-7'],
	'223' => [ 'ML', 'Mali','-8'],
	'356' => [ 'MT', 'Malta','-7'],
	'1670' => [ '', 'Mariana Is','1'],
	'596' => [ '', 'Martinique','-12'],
	'230' => [ 'MU', 'Mauritius','-4'],
	'52' => [ 'MX', 'Mexico','-15'],
	'MD' => [ ' Republic of"', '"Moldova','373'],
	'377' => [ 'MC', 'Monaco','-7'],
	'976' => [ 'MN', 'Mongolia','0'],
	'1664' => [ 'MS', 'Montserrat Is','-12'],
	'212' => [ 'MA', 'Morocco','-6'],
	'258' => [ 'MZ', 'Mozambique','-6'],
	'264' => [ 'NA', 'Namibia','-7'],
	'674' => [ 'NR', 'Nauru','4'],
	'977' => [ 'NP', 'Nepal','-2.3'],
	'599' => [ '', 'Netheriands Antilles','-12'],
	'31' => [ 'NL', 'Netherlands','-7'],
	'64' => [ 'NZ', 'New Zealand','4'],
	'505' => [ 'NI', 'Nicaragua','-14'],
	'227' => [ 'NE', 'Niger','-8'],
	'234' => [ 'NG', 'Nigeria','-7'],
	'850' => [ 'KP', 'North Korea','1'],
	'47' => [ 'NO', 'Norway','-7'],
	'968' => [ 'OM', 'Oman','-4'],
	'92' => [ 'PK', 'Pakistan','-2.3'],
	'507' => [ 'PA', 'Panama','-13'],
	'675' => [ 'PG', 'Papua New Cuinea','2'],
	'595' => [ 'PY', 'Paraguay','-12'],
	'51' => [ 'PE', 'Peru','-13'],
	'63' => [ 'PH', 'Philippines','0'],
	'48' => [ 'PL', 'Poland','-7'],
	'689' => [ 'PF', 'French Polynesia','3'],
	'351' => [ 'PT', 'Portugal','-8'],
	'1787' => [ 'PR', 'Puerto Rico','-12'],
	'974' => [ 'QA', 'Qatar','-5'],
	'262' => [ '', 'Reunion','-4'],
	'40' => [ 'RO', 'Romania','-6'],
	'7' => [ 'RU', 'Russia','-5'],
	'1758' => [ 'LC', 'Saint Lueia','-12'],
	'1784' => [ 'VC', 'Saint Vincent','-12'],
	'684' => [ '', 'Samoa Eastern','-19'],
	'685' => [ '', 'Samoa Western','-19'],
	'378' => [ 'SM', 'San Marino','-7'],
	'239' => [ 'ST', 'Sao Tome and Principe','-8'],
	'966' => [ 'SA', 'Saudi Arabia','-5'],
	'221' => [ 'SN', 'Senegal','-8'],
	'248' => [ 'SC', 'Seychelles','-4'],
	'232' => [ 'SL', 'Sierra Leone','-8'],
	'65' => [ 'SG', 'Singapore','0.3'],
	'421' => [ 'SK', 'Slovakia','-7'],
	'386' => [ 'SI', 'Slovenia','-7'],
	'677' => [ 'SB', 'Solomon Is','3'],
	'252' => [ 'SO', 'Somali','-5'],
	'27' => [ 'ZA', 'South Africa','-6'],
	'34' => [ 'ES', 'Spain','-8'],
	'94' => [ 'LK', 'Sri Lanka','0'],
	'1758' => [ 'LC', 'St.Lucia','-12'],
	'1784' => [ 'VC', 'St.Vincent','-12'],
	'249' => [ 'SD', 'Sudan','-6'],
	'597' => [ 'SR', 'Suriname','-11.3'],
	'268' => [ 'SZ', 'Swaziland','-6'],
	'46' => [ 'SE', 'Sweden','-7'],
	'41' => [ 'CH', 'Switzerland','-7'],
	'963' => [ 'SY', 'Syria','-6'],
	'886' => [ 'TW', 'Taiwan','0'],
	'992' => [ 'TJ', 'Tajikstan','-5'],
	'255' => [ 'TZ', 'Tanzania','-5'],
	'66' => [ 'TH', 'Thailand','-1'],
	'228' => [ 'TG', 'Togo','-8'],
	'676' => [ 'TO', 'Tonga','4'],
	'1809' => [ 'TT', 'Trinidad and Tobago','-12'],
	'216' => [ 'TN', 'Tunisia','-7'],
	'90' => [ 'TR', 'Turkey','-6'],
	'993' => [ 'TM', 'Turkmenistan','-5'],
	'256' => [ 'UG', 'Uganda','-5'],
	'380' => [ 'UA', 'Ukraine','-5'],
	'971' => [ 'AE', 'United Arab Emirates','-4'],
	'44' => [ 'GB', 'United Kiongdom','-8'],
	'1' => [ 'US', 'United States of America','-13'],
	'598' => [ 'UY', 'Uruguay','-10.3'],
	'233' => [ 'UZ', 'Uzbekistan','-5'],
	'58' => [ 'VE', 'Venezuela','-12.3'],
	'84' => [ 'VN', 'Vietnam','-1'],
	'967' => [ 'YE', 'Yemen','-5'],
	'381' => [ 'YU', 'Yugoslavia','-7'],
	'263' => [ 'ZW', 'Zimbabwe','-6'],
	'243' => [ 'ZR', 'Zaire','-7'],
	'260' => [ 'ZM', 'Zambia','-6'],
);
	$number =~ s/\+//;	
	
	for (4,3,2,1) {
		my $code = substr($number, 0, $_);
		return $C{$code}->[0] if $C{$code}->[0];
	}
	
	return '';	
}

sub check_ip {
	
	unless ($query{tenant} && $query{ext} && $query{ip}) {
		print "0:arg error";
		exit 0;
	}
	
	my $sql = "select ip,allowcountry from  v_extensions,vconnect_widget,widget_blacklist " .
						"where v_extensions.extension_uuid=vconnect_widget.extension_uid and " .
						"vconnect_widget.widgetid=widget_blacklist.widgetid and extension=? and ip=?";
	
	my $sth = $dbh->prepare($sql);
	$sth   -> execute($query{ext},$query{ip});
	my $row = $sth->fetchrow_hashref();
	
	if ($row->{ip}) {
		print "0:ip=$query{ip} forbidden";
		exit 0;
	}
	$row->{allowcountry} ||= 'us,cn';
	
	my $country = lc get_country($remote_ip);
	if ($row->{allowcountry} ne 'any' && index(",$row->{allowcountry},", $country) == -1) {
		print "0:ip=$query{ip}($country) is not in the list of allowed countries";
		exit 0;
	}

	print "1:ok";
}

sub get_did {
	my $order = $query{order} || 1;
	if (!$query{widgetid}) {		
		print j({error => '0', 'message' => 'ok: no widgetid define', 'actionid' => $query{actionid}});
		exit 0;
	}
	
	my $sth = $dbh->prepare("select extension,widgetid,did from v_extensions,vconnect_widget " .
							"where v_extensions.extension_uuid=vconnect_widget.extension_uid  and widgetid=?");
	
	$sth   -> execute($query{widgetid});
	my $row = $sth->fetchrow_hashref();
	
	my $extension = $row->{extension};

	if ($row->{did}) {
		print j({error => '0', 'message' => 'ok: did already ordered', 'actionid' => $query{actionid},  did => $row->{did}});
		exit 0;
	}
	
	my $sql = "select forward_all_destination from v_extensions,vconnect_widget " .
			  "where v_extensions.extension_uuid=vconnect_widget.extension_uid and widgetid=?";
	$sth = $dbh->prepare($sql);
	$sth->execute($query{widgetid});
	$row = $sth->fetchrow_hashref();
	
	my $forwardnumber = $row->{forward_all_destination};
	my $number        = get_local_number($forwardnumber);
	if (!$number) {
		print j({error => '0', 'message' => "Error: cant find did by forwardnumber=$forwardnumber", 'actionid' => $query{actionid}});
		exit 0
	}
	
	if ($order) {
		my $s = order_did($number, $extension); #$forwardnumber);
		if (!$s) {
			print j({error => '0', 'message' => "Error:fail to order did=$number", 'actionid' => $query{actionid}});
			exit 0
		}
		
		$dbh->prepare("update vconnect_widget set did=? where widgetid=?")
			->execute($number, $query{widgetid});
		
	}
	
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid},  did => $number});
}


sub get_tollfreedid {
	my $order = $query{order} || 1;
	if (!$query{widgetid}) {		
		print j({error => '0', 'message' => 'ok: no widgetid define', 'actionid' => $query{actionid}});
		exit 0;
	}
	
	my $sth = $dbh->prepare("select extension,widgetid,tollfreedid did from v_extensions,vconnect_widget " .
							"where v_extensions.extension_uuid=vconnect_widget.extension_uid and widgetid=?");
	$sth   -> execute($query{widgetid});
	my $row = $sth->fetchrow_hashref();
	my $extension = $row->{extension};
	
	if ($row->{did}) {
		print j({error => '0', 'message' => 'ok: tollfreedid already ordered', 'actionid' => $query{actionid},  did => $row->{did}});
		exit 0;
	}
	
	my $sql = "select forward_all_destination from v_extensions,vconnect_widget " .
			  "where v_extensions.extension_uuid=vconnect_widget.extension_uid and widgetid=?";
	$sth = $dbh->prepare($sql);
	$sth->execute($query{widgetid});
	$row = $sth->fetchrow_hashref();
	
	my $forwardnumber = $row->{forward_all_destination};

	my $number        = get_tollfree_number($forwardnumber);
	if (!$number) {
		print j({error => '0', 'message' => "Error: cant find did by forwardnumber=$forwardnumber", 'actionid' => $query{actionid}});
		exit 0
	}
	
	if ($order) {
		my $s = order_tollfree_did($number, $extension);
		if (!$s) {
			print j({error => '0', 'message' => "Error:fail to order did=$number", 'actionid' => $query{actionid}});
			exit 0
		}
		
		$dbh->prepare("update vconnect_widget set tollfreedid=? where widgetid=?")
			->execute($number, $query{widgetid});
		
	}
	
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid},  did => $number});
}

sub get_local_number {
	my $number = shift || return;
	my ($npa)  = $number =~ /^(?:1|)(\d\d\d)/;
	$npa ||= 818;
	warn $npa;
	if ($npa eq '800' || $npa eq '811' || $npa eq '822'|| $npa eq '833'|| $npa eq '844'|| $npa eq '855'
	    || $npa eq '866'|| $npa eq '877'|| $npa eq '888'|| $npa eq '899') {
		$npa = '818';
	}
	
	return unless $config{api_login} && $config{api_pass};
	my $url    = "http://api.vitelity.net/api.php?login=$config{api_login}&pass=$config{api_pass}&cmd=listnpa&npa=$npa";
	warn $url;
	my $body  = get $url;
	my ($did) = $body =~ /($npa\d{7}),.+?,X/;
	
	return $did;
	
}

sub get_tollfree_number {
	my $number = shift;
	my ($npa)  = $number =~ /^(\d\d\d)/;
	return unless $npa;
	return unless $config{api_login} && $config{api_pass};
	my $url    = "http://api.vitelity.net/api.php?login=$config{api_login}&pass=$config{api_pass}&cmd=listtollfree";
	warn $url;
	my $body  = get $url;
	my ($did) = $body =~ /\[\[(\d{10})/;
	
	return $did;
	
}

sub order_did {
	my $did 	= shift || return;
	my $forward =  shift;
	return unless $config{api_login} && $config{api_pass};
	
	my $body  = get "http://api.vitelity.net/api.php?login=$config{api_login}&pass=$config{api_pass}&cmd=getlocaldid&did=$did" ;
	
	if ($body =~ /success/) {
		$body = get "http://api.vitelity.net/api.php?login=$config{api_login}&pass=$config{api_pass}&cmd=reroute&routesip=$HOSTIP&did=$did";
		warn "$did:$forward ordered OK!";
		
		my $url = "http://$HOSTNAME/app/dialplan_inbound/dialplan_inbound_add.php?action=advanced";
		$ua->request(POST $url,
                    ['dialplan_name' => "$did-$forward", 'condition_field_1' => 'destination_number', 'condition_expression_1' => "^$did\$",
					 'action_1' => "transfer:$forward XML $HOSTNAME", 'action_2' => "set:fromdid=$did", 'dialplan_enabled' => 'true',
					 'dialplan_description' => "inbound did for $forward", 'submit' => 'Save']
                );
		$ua->request(GET "http://$HOSTNAME/");

		return 1;
	} else {
		warn "did:$did [FAILED]\n$body";
		return;
	}	
}

sub add_widgetdid {
	if (!$query{widgetid}) {		
		print j({error => '1', 'message' => 'error: no widgetid define', 'actionid' => $query{actionid}});
		exit 0;
	}
	
	my $sth = $dbh->prepare("select extension,widgetid,did from v_extensions,vconnect_widget " .
							"where v_extensions.extension_uuid=vconnect_widget.extension_uid  and widgetid=?");
	
	$sth   -> execute($query{widgetid});
	my $row = $sth->fetchrow_hashref();
	
	my $did 	= $query{did};
	my $forward = $row->{extension};
	
	if ($did && $forward) {	
	
		my $url = "http://$HOSTNAME/app/dialplan_inbound/dialplan_inbound_add.php?action=advanced";
		$ua->request(POST $url,
                    ['dialplan_name' => "$did-$forward", 'condition_field_1' => 'destination_number', 'condition_expression_1' => "^$did\$",
					 'action_1' => "transfer:$forward XML $HOSTNAME", 'action_2' => "set:fromdid=$did", 'dialplan_enabled' => 'true',
					 'dialplan_description' => "inbound did for $forward", 'submit' => 'Save']
                );
		$ua->request(GET "http://$HOSTNAME/");

	} else {
		print j({error => '1', 'message' => 'error: did or extension define', 'actionid' => $query{actionid}});
		exit 0;
	}
	
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}});
}

sub add_directdid {
	
	my $did = $query{did};
	if (!$did) {
		print j({error => '1', 'message' => 'did is null', 'actionid' => $query{actionid}});
		exit;
	}
	
	my $country  =$query{country} || get_country($did);
	$country   ||= 'us';
	$country     = lc $country;
	my $channels = $query{channels} || 2;
	
	$dbh->prepare("delete from vconnect_dids where did=?")
		->execute($did);
		
	my $sth = $dbh->prepare("insert into vconnect_dids (did,country,channels) values (?, ?, ?)");
	$sth   -> execute($did, $country, $channels);
	
	my $url = "http://$HOSTNAME/app/dialplan_inbound/dialplan_inbound_add.php?action=advanced";
		$ua->request(POST $url,
                    ['dialplan_name' => "$did-directdial", 'condition_field_1' => 'destination_number', 'condition_expression_1' => "^($did)\$",
					 'action_2' => "transfer:directdial$did XML $HOSTNAME", 'action_1' => "set:fromdid=$did", 'dialplan_enabled' => 'true',
					 'dialplan_description' => "set directdial for  did=$did", 'submit' => 'Save']
                );
	$ua->request(GET "http://$HOSTNAME/");
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}, country => $country});
}


sub order_tollfree_did {
	my $did 	= shift || return;
	my $forward =  shift;
	return unless $config{api_login} && $config{api_pass};
	
	my $url = "http://api.vitelity.net/api.php?login=$config{api_login}&pass=$config{api_pass}&cmd=gettollfree&did=$did";
	warn $url;
	$body   = get $url;
	
	
	if ($body =~ /success/) {
		$body = get "http://api.vitelity.net/api.php?login=$config{api_login}&pass=$config{api_pass}&cmd=reroute&routesip=$HOSTIP&did=$did";
		warn "$did:$forward ordered OK!";
		
		my $url = "http://$HOSTNAME/app/dialplan_inbound/dialplan_inbound_add.php?action=advanced";
		$ua->request(POST $url,
                    ['dialplan_name' => "$did-$forward", 'condition_field_1' => 'destination_number', 'condition_expression_1' => "^$did\$",
					 'action_1' => "transfer:$forward XML $HOSTNAME", 'action_2' => "set:fromdid=$did", 'dialplan_enabled' => 'true',
					 'dialplan_description' => "inbound did for $forward", 'submit' => 'Save']
                );
		
		$ua->request(GET "http://$HOSTNAME/");
		return 1;
	} else {
		warn "did:$did [FAILED]$url:$body"; 
		return;
	}		
}

sub set_recording {
	my $order = $query{order} || 1;
	if (!$query{widgetid}) {		
		print j({error => '0', 'message' => 'ok: no widgetid define', 'actionid' => $query{actionid}});
		exit 0;
	}
	
	my $enable = $query{enable} ? 'true' : 'false';
	

	my $sth = $dbh->prepare("select extension,widgetid,did from v_extensions,vconnect_widget " .
							"where v_extensions.extension_uuid=vconnect_widget.extension_uid  and widgetid=?");
	
    $sth   -> execute($query{widgetid});
    
    my $row = $sth->fetchrow_hashref();
    if (!$row->{extension}) {
        print j({error => '1', 'message' => 'internal error: no available ext', 'actionid' => $query{actionid}});
        exit 0;
    }
	
	my $exten = $row->{extension};
	
	my $result = `fs_cli -rx 'db insert/vconnect_record/$exten/$enable'`;
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid},'widgetid' => $query{widgetid}, result => $result});
}

sub get_register {
	if (!$query{widgetid}) {		
		print j({error => '0', 'message' => 'ok: no widgetid define', 'actionid' => $query{actionid}});
		exit 0;
	}
	
	my $sql = "select extension from v_extensions,vconnect_widget where v_extensions.extension_uuid=vconnect_widget.extension_uid and (widgetid='$query{widgetid}')" ;
	warn $sql;
	my $sth = $dbh->prepare($sql);	
	$sth->execute();
	
	my $row = $sth->fetchrow_hashref;
	my $ext = $row->{extension};
	my $domain = 'sipvconnect.velantro.net';
	$sth = $dbh->prepare("select password from v_extensions where user_context=? and extension=?");
	$sth ->execute($domain, $ext);
	
	$row = $sth->fetchrow_hashref;
	
	if (!$ext) {
		print j({error => '0', 'message' => "ok: widgetid=$query{widgetid} is not binded to any extension", 'actionid' => $query{actionid}});
		exit 0;#code
	}
	
	my $status = 'Unregistered';
	
	for (split /\n/, `sudo /usr/local/bin/fs_cli -rx "show registrations"`) {
		if (index(",$_,", $ext) != -1 && index(",$_,", $domain) != -1) {
			$status = 'Registered';
			last;
		}		
	}
	
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid},'widgetid' => $query{widgetid},extension => $ext, password => $row->{password}, host => $domain, status => $status});
}

sub save_sms {
	my $msgid = $query{msgid};
	my $src	  = $query{src};
	my $dst   = $query{dst};
	my $msg	  = $query{msg};
	
	$dbh->prepare("insert into v_sms (msgid,src,dst,msg) values (?,?,?,?)")
		->execute($msgid, $src, $dst, $msg);
		
	return "OK";
}

sub update_voicemail {
	if (!$query{widgetid}) {		
		print j({error => '0', 'message' => 'ok: no widgetid define', 'actionid' => $query{actionid}});
		exit 0;
	}
	
	my $sql = "select domain_uuid,extension,extension_uuid,password,recording from v_extensions,vconnect_widget where v_extensions.extension_uuid=vconnect_widget.extension_uid and (widgetid='$query{widgetid}')" ;
	warn $sql;
	my $sth = $dbh->prepare($sql);	
	$sth->execute();	
	my $row = $sth->fetchrow_hashref;
	
	my $ext 	= $row->{extension};
	my $domain_uuid = $row->{domain_uuid};
	unless ($ext && $domain_uuid) {
		print j({error => '0', 'message' => "ok: widgetid=$query{widgetid} is not binded to any extension", 'actionid' => $query{actionid}});
		exit 0;
	}
	

	my $mailto 	= $query{mailto}	 || $row->{voicemail_mail_to};
	my $attachfile  = $query{attachfile} 	 || $row->{voicemail_attach_file};
	my $keeplocal	= $query{keeplocal}	 || $row->{voicemail_local_after_email};
	my $enabled	= $query{enabled}	 || $row->{voicemail_enabled};
	my $recording	= $query{recording}	 || $row->{recording};

	_update_voicemail($row->{extension_uuid}, $row->{extension}, $row->{password}, $mailto, $attachfile, $keeplocal, $enabled, $recording);

	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}});	
}


sub update_voicemailgreeting {
	if (!$query{widgetid}) {		
		print j({error => '0', 'message' => 'ok: no widgetid define', 'actionid' => $query{actionid}});
		exit 0;
	}
	
	my $sql = "select user_context,extension,domain_uuid from v_extensions,vconnect_widget where v_extensions.extension_uuid=vconnect_widget.extension_uid and (widgetid='$query{widgetid}')" ;
	warn $sql;
	my $sth = $dbh->prepare($sql);	
	$sth->execute();	
	my $row = $sth->fetchrow_hashref;
	
	my $ext 	= $row->{extension};
	my $domain = $row->{user_context};
	unless ($ext && $domain) {
		print j({error => '0', 'message' => "ok: widgetid=$query{widgetid} is not binded to any extension", 'actionid' => $query{actionid}});
		exit 0;
	}
	my $wavurl = $query{greetingwavurl};
	if (!$wavurl) {		
		print j({error => '0', 'message' => 'ok: wavurl define', 'actionid' => $query{actionid}});
		exit 0;
	}
	
	system("wget --no-check-certificate \"$wavurl\" -O  /usr/local/freeswitch/storage/voicemail/default/$domain/$ext/greeting_1.wav");
	$dbh->prepare("update v_voicemails set greeting_id=1 where  domain_uuid=? and voicemail_id=?")
	    ->execute($row->{domain_uuid}, $ext);
	
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}});	
		
}

sub remove_voicemailgreeting {
	if (!$query{widgetid}) {		
		print j({error => '0', 'message' => 'ok: no widgetid define', 'actionid' => $query{actionid}});
		exit 0;
	}
	
	my $sql = "select user_context,extension,domain_uuid from v_extensions,vconnect_widget where v_extensions.extension_uuid=vconnect_widget.extension_uid and (widgetid='$query{widgetid}')" ;
	warn $sql;
	my $sth = $dbh->prepare($sql);	
	$sth->execute();	
	my $row = $sth->fetchrow_hashref;
	
	my $ext 	= $row->{extension};
	my $domain = $row->{user_context};
	unless ($ext && $domain) {
		print j({error => '0', 'message' => "ok: widgetid=$query{widgetid} is not binded to any extension", 'actionid' => $query{actionid}});
		exit 0;
	}
	
	unlink "/usr/local/freeswitch/storage/voicemail/default/$domain/$ext/greeting_1.wav";
	
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}});		
}

sub get_directdialdid {
	if (!$query{widgetid}) {		
		print j({error => '1', 'message' => 'error: no widgetid define', 'actionid' => $query{actionid}});
		exit 0;
	}

	my $sql = "select extension,widgetid from v_extensions,vconnect_widget where v_extensions.extension_uuid=vconnect_widget.extension_uid and widgetid=?" ;

	my $sth = $dbh->prepare($sql);	
	$sth->execute($query{widgetid});
	my $row    =  $sth->fetchrow_hashref;
	my $exten  =  substr($row->{extension}, 2, 4);
	
	my $country = $query{country} || 'us';
	my $cond    = '';
	$sth    	= $dbh->prepare("select did,channels from vconnect_dids where country=? $cond limit 1");
	$sth	   -> execute($country);
	my $did     =  '';

	while ($row = $sth->fetchrow_hashref) {
		if (check_did_available($row->{did}, $row->{channels})) {
			$did = $row->{did};
			last;
		}
	}
	
	if ($exten && $did) {
		print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}, directdid => $did, extension => $exten});
	} else {
		print j({error => '1', 'message' => 'no directdid or extension found', 'actionid' => $query{actionid}});

	}
}

sub get_dashboard {
	if (!$query{widgetid}) {		
		print j({error => '1', 'message' => 'ok: no widgetid define', 'actionid' => $query{actionid}});
		exit 0;
	}
	
	my $sth = $dbh->prepare("select extension,widgetid,did,liverecordings,livevoicemails,this_month_calls,last_month_calls,last_30days_calls,this_month_voicemails,last_month_voicemails,this_month_answeredcalls,last_month_answeredcalls from v_extensions,vconnect_widget " .
							"where v_extensions.extension_uuid=vconnect_widget.extension_uid  and widgetid=?");
	
	$sth   -> execute($query{widgetid});
	my $row = $sth->fetchrow_hashref();
	
	my $extension 	   = $row->{extension};
	my $liverecordings = $row->{liverecordings} || 0;
	my $livevoicemails = $row->{livevoicemails} || 0;
	
=pod	
	my $cnt	= int (`fs_cli -rx "db select/livecalls/$extension"`);
	$cnt  ||= 0;
	
=cut
	my $channels = `fs_cli -rx "show channels"`;
	my $cnt      = 0;
	for my $line (split /\n/, $channels) {
		my @f = split ',', $line;
		$cnt++ if $f[1] eq 'inbound' && $f[7] eq $extension;
	}
	
	warn "$extension: $cnt";
	
	$sql = "select count(*) total from v_xml_cdr where caller_id_number='$extension' and hangup_cause =	 'NORMAL_CLEARING'";

	warn $sql;
	$sth = $dbh->prepare($sql);
	
	$sth->execute();
	my $total = $sth->fetchrow_hashref;
	
	

	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}, livecalls => $cnt, liverecordings => $liverecordings,
			livevoicemails => $livevoicemails, answered_calls => $total->{total} || 0,
			this_month_calls => $row->{this_month_calls} || 0, last_month_calls => $row->{last_month_calls} || 0,
			last_30days_calls => $row->{last_30days_calls} || 0, this_month_voicemails => $row->{this_month_voicemails} || 0,
			last_month_voicemails => $row->{last_month_voicemails} || 0,this_month_answeredcalls => $row->{this_month_answeredcalls} || 0,
			last_month_answeredcalls => $row->{last_month_answeredcalls} || 0});

}

sub check_did_available {
	my $did 	   = shift || return;
	my $channels   = shift || 2;
	
	my $cnt	= int (`fs_cli -rx "db select/channels/$did"`);
	$cnt  ||= 0;
	
	warn "$did $channels $cnt";
	return $did if $cnt < $channels;
}

sub update_recordingstorage {
	if (!$query{widgetid}) {		
		print j({error => '0', 'message' => 'ok: no widgetid define', 'actionid' => $query{actionid}});
		exit 0;
	}
	
	my $value = $query{value} || 1;
	$dbh->prepare("update vconnect_widget set recordinglimit=? where widgetid=?")
		->execute($value);
		
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}});	

}

sub update_usage {
	if (-e "/tmp/vconnect.lock") {
		print j({error => '1', 'message' => 'other process is running ...', 'actionid' => $query{actionid}});	
	}
	
	system("touch /tmp/vconnect.lock");
	
	my $day = shift;
	my $basedir = '/usr/local/freeswitch/recordings/vconnect.velantro.net/archive';
	if ($day ne 'all') {
		my ($y, $m, $d) = get_today();
		$basedir .= "/$y/$m/$d"
	}
	
	my %spool = ();
	my $sth = $dbh->prepare("select widgetid from vconnect_widget,v_xml_cdr where vconnect_widget.extension_uid=v_xml_cdr.extension_uuid and uuid=?");
	for my $f (split /\n/, `find $basedir -name "*.wav"`) {
		my ($uuid) = $f =~ m{([^\/\\]+?)\.wav$};
		$sth->execute($uuid);
		my $row = $sth->fetchrow_hashref;
		next if !$row->{widgetid};
		$spool{recordings}{$row->{widgetid}} += -s $f;
		#warn "$uuid: $row->{widgetid}";
	}
	
	$sth = $dbh->prepare("select widgetid,month(start_stamp) mth,unix_timestamp(start_stamp) ts,hangup_cause from vconnect_widget,v_xml_cdr where vconnect_widget.extension_uid=v_xml_cdr.extension_uuid and start_stamp >= date_sub(now(), interval 61 day)");
	
	my @f = localtime();
	my $this_month = $f[4] + 1;
	my $last_month = ($this_month > 1 ? $this_month-1 : 12);
	my $last_30days_time = time - 3600 * 24 * 30;
	$sth -> execute();
	while (my $row = $sth->fetchrow_hashref) {
		if ($row->{mth} == $this_month) {
			$spool{this_month_calls}{$row->{widgetid}}++;
			if ($row->{hangup_cause} eq 'NORMAL_CLEARING') {
				$spool{this_month_answeredcalls}{$row->{widgetid}}++;
			}
		}
		
		if ($row->{mth} == $last_month) {
			$spool{last_month_calls}{$row->{widgetid}}++;
			if ($row->{hangup_cause} eq 'NORMAL_CLEARING') {
				$spool{last_month_answeredcalls}{$row->{widgetid}}++;
			}
		}
		
		if ($row->{ts} >= $last_30days_time) {
			$spool{last_30days_calls}{$row->{widgetid}}++;			
		}
	}
	
	$sth = $dbh->prepare("select voicemail_message_uuid,caller_id_number,month(from_unixtime(created_epoch)) mth from v_voicemail_messages");
	$sth -> fetchrow_hashref;
	
	%vmspool = ();
	while ($row = $sth->fetchrow_hashref) {
		$vmspool{$row->{voicemail_message_uuid}}{extension} = $row->{caller_id_number};
		$vmspool{$row->{voicemail_message_uuid}}{mth} = $row->{mth};
	}	
	
	
	$sth = $dbh->prepare("select widgetid,extension from vconnect_widget,v_extensions where vconnect_widget.extension_uid=v_extensions.extension_uuid and  domain_uuid='9c060822-026a-492d-bb08-8a88a6249631'");
	$sth -> execute();
	while (my $row = $sth->fetchrow_hashref) {
		my $vm_dir = "/usr/local/freeswitch/storage/voicemail/default/vconnect.velantro.net/$row->{extension}";
		if (-d $vm_dir) {
			#my ($byte) = split /\s+/, `du -s $vm_dir`;
			#$spool{voicemails}{$row->{widgetid}} = $byte;
			#warn "$row->{extension}: $byte";
			
			for (glob "$vm_dir/*") {
				$spool{voicemails}{$row->{widgetid}}++;
				my ($vmuid) =  $_ =~ /msg_(.+?)\.wav/;
				if ($vmspool{$vmuid}{mth} == $this_month) {
					$spool{this_month_voicemails}{$row->{widgetid}}++;
				}
				
				if ($vmspool{$vmuid}{mth} == $last_month) {
					$spool{last_month_voicemails}{$row->{widgetid}}++;
				}
			}
		}
		
		
	}
	
	$dbh->prepare("update vconnect_widget set liverecorddings=0,livevoicemails=0,this_month_calls=0,last_month_calls=0,last_30days_calls=0,this_month_voicemails=0,last_month_voicemails,this_month_answeredcalls=0,last_month_answeredcalls=0")->execute();
	
	for (keys %{$spool{recordings}}) {
		$dbh->prepare("update vconnect_widget set liverecordings=? where widgetid=?")
			->execute($spool{recordings}{$_}, $_);
		warn "recordings - $_: $spool{recordings}{$_}";
	}
	
	for (keys %{$spool{voicemails}}) {
		$dbh->prepare("update vconnect_widget set livevoicemails=? where widgetid=?")
			->execute($spool{voicemails}{$_}, $_);
		warn "voicemails - $_: $spool{voicemails}{$_}";	
	}
	
	for (keys %{$spool{this_month_calls}}) {
		$dbh->prepare("update vconnect_widget set this_month_calls=? where widgetid=?")
			->execute($spool{this_month_calls}{$_}, $_);
		warn "this_month_calls - $_: $spool{this_month_calls}{$_}";	
	}
	
	for (keys %{$spool{last_month_calls}}) {
		$dbh->prepare("update vconnect_widget set last_month_calls=? where widgetid=?")
			->execute($spool{last_month_calls}{$_}, $_);
		warn "last_month_calls - $_: $spool{last_month_calls}{$_}";	
	}
	
	for (keys %{$spool{last_30days_calls}}) {
		$dbh->prepare("update vconnect_widget set last_30days_calls=? where widgetid=?")
			->execute($spool{last_30days_calls}{$_}, $_);
		warn "last_30days_calls - $_: $spool{last_30days_calls}{$_}";	
	}
	
	for (keys %{$spool{this_month_voicemails}}) {
		$dbh->prepare("update vconnect_widget set this_month_voicemails=? where widgetid=?")
			->execute($spool{this_month_voicemails}{$_}, $_);
		warn "this_month_voicemails - $_: $spool{this_month_voicemails}{$_}";	
	}	
	
	for (keys %{$spool{last_month_voicemails}}) {
		$dbh->prepare("update vconnect_widget set last_month_voicemails=? where widgetid=?")
			->execute($spool{last_month_voicemails}{$_}, $_);
		warn "last_month_voicemails - $_: $spool{last_month_voicemails}{$_}";	
	}
	
	for (keys %{$spool{this_month_answeredcalls}}) {
		$dbh->prepare("update vconnect_widget set this_month_answeredcalls=? where widgetid=?")
			->execute($spool{this_month_answeredcalls}{$_}, $_);
		warn "this_month_answeredcalls - $_: $spool{this_month_answeredcalls}{$_}";	
	}

	for (keys %{$spool{last_month_answeredcalls}}) {
		$dbh->prepare("update vconnect_widget set last_month_answeredcalls=? where widgetid=?")
			->execute($spool{last_month_answeredcalls}{$_}, $_);
		warn "last_month_answeredcalls - $_: $spool{last_month_answeredcalls}{$_}";	
	}
	
	unlink "/tmp/vconnect.lock";
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}});	

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
	#my $result = `fs_cli -rx "originate {origination_caller_id_name=callback-$ext,origination_caller_id_number=8188886666,domain_name=$HOSTNAME,origination_uuid=$uuid}loopback/$ext/$HOSTNAME/XML $dest XML $HOSTNAME"`;
	if ($dest =~ /^\+(\d+)$/) {
		$dest = "011$1";
	}
	
	$dest	  =~ s/\D//g;

	if ($dest =~ /^\d{10}$/) {
		$dest = "1$dest";
	}
	
	my $callerid = $query{callerid} || '8188886666';

	my $result = `fs_cli -rx "bgapi originate {execute_on_answer='lua callback.lua startmoh $uuid $query{widgetid}',ringback=local_stream://default,ignore_early_media=true,fromextension=$ext,origination_caller_id_name=callback-$ext,origination_caller_id_number=$callerid,outbound_caller_id_number=$callerid,outbound_caller_id_name=callback-$ext,domain_name=$HOSTNAME,origination_uuid=$uuid,sip_h_X-accountcode=6915654132}loopback/$ext/$HOSTNAME/XML $dest XML $HOSTNAME"`; #sofia/gateway/vconnect.velantro.net-newa2b/$dest $ext XML $HOSTNAME"`;
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
	
	#my $result = `fs_cli -rx "originate {origination_caller_id_name=callback-$ext,origination_caller_id_number=8188886666,domain_name=$HOSTNAME,origination_uuid=$uuid}loopback/$ext/$HOSTNAME/XML $dest XML $HOSTNAME"`;
	if ($dest =~ /^\+(\d+)$/) {
		$dest = "011$1";
	}
	
	my $forward_type = `fs_cli -rx "db select/vconnect_dsttype/$ext"`;
	my $forward_dest = `fs_cli -rx "db select/vconnect/$ext"`;
	
	if ($forward_dest =~ /^\+(\d+)$/) {
		$forward_dest = "011$1";
	}
	
	
	my $reg_txt = `fs_cli -rx "show registrations"`;
	
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
	my $conf_list = `fs_cli -rx "conference $ext list"`;
	for (split /\n/, $conf_list) {
		if (index($_, "loopback/$forward_dest-a") != -1) {
			$is_widget_in_conference = 1;
			last;
		}
	}
	my $result = `fs_cli -rx "conference $ext kick non_moderator"`;
	
	if (!$is_widget_in_conference) {
		my $result = `fs_cli -rx "originate {origination_caller_id_name=callback-$ext,origination_caller_id_number=$callerid,domain_name=$HOSTNAME,ignore_early_media=true,origination_uuid=$uuid,flags=endconf|moderator}loopback/$forward_dest/$HOSTNAME/XML conference$ext XML $HOSTNAME"`;
		sleep 2;
		
		my $call_list = `fs_cli -rx "show calls"`;
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
	$result = `fs_cli -rx "bgapi originate {origination_caller_id_name=callback-$ext,origination_caller_id_number=$callerid;,domain_name=$HOSTNAME,origination_uuid=$uuid,autocallback_fromextension=$ext,is_lead=1}loopback/$dest/$HOSTNAME/XML conference$ext XML $HOSTNAME"`;
	
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
	#my $result = `fs_cli -rx "originate {origination_caller_id_name=callback-$ext,origination_caller_id_number=8188886666,domain_name=$HOSTNAME,origination_uuid=$uuid}loopback/$ext/$HOSTNAME/XML $dest XML $HOSTNAME"`;
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
	
	
	# bgapi originate {ignore_early_media=true,fromextension=188,origination_caller_id_name=8882115404,origination_caller_id_number=8882115404,effective_caller_id_number=8882115404,effective_caller_id_name=8882115404,domain_name=vip.velantro.net,origination_uuid=14061580998073}loopback/188/vip.velantro.net 8882115404 XML vip.velantro.net
	#my $result = `$fs_cli -rx "bgapi originate {ringback=local_stream://default,ignore_early_media=true,absolute_codec_string=PCMU,fromextension=$ext,origination_caller_id_name=$dest,origination_caller_id_number=$dest,effective_caller_id_number=$cid,effective_caller_id_name=$cid,domain_name=$domain,outbound_caller_id_number=$cid,$alert_info,origination_uuid=$uuid,$auto_answer}loopback/$ext/$domain $realdest XML $domain"`;
	my $result = `$fs_cli -rx "bgapi originate {ringback=local_stream://default,ignore_early_media=true,absolute_codec_string=PCMU,fromextension=$ext,origination_caller_id_name=$dest,origination_caller_id_number=$dest,effective_caller_id_number=$dest,effective_caller_id_name=$dest,domain_name=$domain,outbound_caller_id_number=$dest,$alert_info,origination_uuid=$uuid,$auto_answer}user/$ext\@$domain &bridge([origination_caller_id_name=$cid,origination_caller_id_number=$cid,effective_caller_id_number=$cid,effective_caller_id_name=$cid,iscallback=$ext,outbound_caller_id_number=$cid,user_record=all,record_session=true]loopback/$dest/$domain)"`;
	
	if ($query{from} eq 'firefox') {
		template_print($template_file, {error => '0', 'message' => 'ok', 'actionid' => $query{actionid},callbackid => $uuid,dest=>$dest, src => $ext});
	} else {
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

sub start_moh {
	my $uuid = $query{uuid};
	my $path = "/usr/local/freeswitch/sounds/music/8000/$query{widgetid}.wav";
	my $res = `fs_cli -rx "uuid_broadcast $uuid $path"`;

	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}});
}

sub stop_moh {
	my $uuid = $query{uuid};
	my $uuid2 = $query{otheruuid};
	
	my $res = `fs_cli -rx "uuid_bridge $uuid $uuid2"`;

	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}});
}

sub hangup {
	my $uuid = $query{uuid} || $query{callbackid};

=pod	
	my $channels = `fs_cli -rx "show channels"`;
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

	my $res = `fs_cli -rx "uuid_kill $uuid"`;
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
	$res = `fs_cli -rx "uuid_kill $uuid"`;
	

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
		my $channels = `fs_cli -rx "show channels"`;
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
	
	$res = `fs_cli -rx "uuid_transfer $uuid  $leg $dest XML $domain"`;
	
	print j({error => '0', 'message' => 'transfer: ok', 'actionid' => $query{actionid}});
}

sub get_callbackstate {
	my $uuid = $query{uuid} || $query{callbackid};

	my %uuid = ();
	my $channels = `fs_cli -rx "show channels"`;
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
				$uuid = $row->{bridge_uuid};
				if ($uuid{$uuid}) {
					$state = 'DESTANSWERED';
				} else {
					$state = 'HANGUP'
				}
			} else {
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
		} else {
			$state = 'EXTWAIT';
		}
	#	$state = 'HANGUP';
	}
	
	warn "$uuid state: $state";
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}, state => $state});	
}

sub get_vconnectincoming {
	
	if (!$query{widgetid}) {		
		print j({error => '1', 'message' => 'ok: no widgetid define', 'actionid' => $query{actionid}});
		exit 0;
	}
	
	my $incoming = shift || 0;
	my $sql = "select user_context,extension,domain_uuid from v_extensions,vconnect_widget where v_extensions.extension_uuid=vconnect_widget.extension_uid and (widgetid='$query{widgetid}')" ;
	warn $sql;
	my $sth = $dbh->prepare($sql);	
	$sth->execute();	
	my $row = $sth->fetchrow_hashref;
	
	my $ext 	= $row->{extension};
	my $channels = `fs_cli -rx "show calls"`;
	
	my $found   = 0;
	my $state   = 'HANGUP';
	my $callerid= '';
	for my $line (split /\n/, $channels) {
		my @f = split ',', $line;
		my $uuid = $f[0];
		
		my $fromextension = `fs_cli -rx "uuid_getvar $uuid fromextension"`;
		chomp $ext;
		if ($ext eq $fromextension) {
			$found = 1;
			my $i  = _call_field2index('call_uuid');
			if (!$f[$i]) {
				$state = 'WAIT';
			} else {			
				$i  = _call_field2index('callstate');
				$state = $f[$i];
			}
			
			$i = _call_field2index('cid_num');
			
			$callerid = $f[$i];
			last;
		}
	}	
	
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}, callerid => $callerid, state => $state});	
}


sub get_autocallstate {
	if (!$query{widgetid}) {		
		print j({error => '1', 'message' => 'ok: no widgetid define', 'actionid' => $query{actionid}});
		exit 0;
	}
	
	my $incoming = shift || 0;
	my $sql = "select user_context,extension,domain_uuid from v_extensions,vconnect_widget where v_extensions.extension_uuid=vconnect_widget.extension_uid and (widgetid='$query{widgetid}')" ;
	warn $sql;
	my $sth = $dbh->prepare($sql);	
	$sth->execute();	
	my $row = $sth->fetchrow_hashref;
	
	my $ext 	= $row->{extension};
	my $channels = `fs_cli -rx "show calls"`;
	
	my $found   = 0;
	my $state   = 'HANGUP';
	my $callerid= '';
	for my $line (split /\n/, $channels) {
		my @f = split ',', $line;
		my $uuid = $f[0];
		
		my $i  = _call_field2index('cid_name');
		if ($f[$i] ne "callback-$ext") {
			next;
		}
		
		my $is_lead = `fs_cli -rx "uuid_getvar $uuid is_lead"`;
		
		chomp $is_lead;
		if ($is_lead == 1) {
			$found = 1;

			
			$i  = _call_field2index('callstate');
			$state = $f[$i];
						
			last;
		}
	}	
	
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}, state => $state});	
}


sub do_autocallhangup {
	if (!$query{widgetid}) {		
		print j({error => '1', 'message' => 'ok: no widgetid define', 'actionid' => $query{actionid}});
		exit 0;
	}
	
	my $incoming = shift || 0;
	my $sql = "select user_context,extension,domain_uuid from v_extensions,vconnect_widget where v_extensions.extension_uuid=vconnect_widget.extension_uid and (widgetid='$query{widgetid}')" ;
	warn $sql;
	my $sth = $dbh->prepare($sql);	
	$sth->execute();	
	my $row = $sth->fetchrow_hashref;
	
	my $ext 	= $row->{extension};
	my $channels = `fs_cli -rx "show calls"`;
	
	my $found   = 0;
	my $state   = 'HANGUP';
	my $callerid= '';
	for my $line (split /\n/, $channels) {
		my @f = split ',', $line;
		my $uuid = $f[0];
		
		my $i  = _call_field2index('cid_name');
		if ($f[$i] ne "callback-$ext") {
			next;
		}
		
		my $is_lead = `fs_cli -rx "uuid_getvar $uuid is_lead"`;
		
		chomp $is_lead;
		if ($is_lead == 1) {
			$found = 1;
			my $res = `fs_cli -rx "uuid_kill $uuid"`;
			last;
		}
	}	
	
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}});	
}

sub do_route53 {
	my $subaction = $query{subaction};
	my $domain	  = $query{domain};
	my $ip		  = $query{ip};
	my $hostzoneid= $query{hostzoneid};
	my $basedomain = '';
	my $hostzoneid = '';
	
	$hostzoneid = "/hostedzone/$hostzoneid";
	
	if ($domain =~ /velantro\.net$/) {
		$basedomain = 'velantro.net';
		$hostzoneid ='/hostedzone/Z3GGFTJ85NN6H0';
	}
	
	if ($domain =~ /velantro\.com/) {
		$basedomain = 'velantro.com';
		$hostzoneid ='/hostedzone/Z3AB13ZF00O45P';
	}
	
	if ($domain =~ /fusionpbx\.cn/) {
		$basedomain = 'velantro.net';
		$hostzoneid ='/hostedzone/Z36W1ESZR9W1TW';
	}
	
	if ($domain =~ /fusionpbx\.cn/) {
		$basedomain = 'velantro.net';
		$hostzoneid ='/hostedzone/Z36W1ESZR9W1TW';
	}
	
	$json =<<J;
{"Comment": "$domain for $basedomain.",
  "Changes": [
    {
      "Action": "$subaction",
      "ResourceRecordSet": {
        "Name": "$domain.",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "$ip"
          }
        ]
      }
    }
  ]
}
J
	my $file = "/tmp/" . time . ".json";
	open W, "> $file";
	print W $json;
	
	$output = `aws route53 change-resource-record-sets --hosted-zone-id "$hostzoneid" --change-batch file://$file`;
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}, 'output' => $output});

}

sub do_aws {
	my $name = $query{name};
	my $value = $query{value};
	my $txt  = '';
	my $file = '';;
	if ($name eq 'region') {
		$file= "/var/www/.aws/config";

	} elsif ($name eq 'aws_access_key_id' || $name eq 'aws_secret_access_key') {
		$file = "/var/www/.aws/credentials";
		_update_s3();
	}
	
	$txt = `cat $file`;
	
	open FH, "> $file";
	
	for (split /\n/, $txt) {
		my ($k, $v) = split / = /, $_, 2;
		if ($k eq $name) {
			print FH "$k = $value\n";
		} else {
			print FH "$_\n";
		}
	}
	
	close FH;
	
	my $output = `cat $file`;
	
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}, 'output' => $output});

}

sub _update_s3 {
	my ($name, $value) = @_;
	my $file = '/etc/passwd-s3fs';
	my $txt = `cat $file`;
	
	my ($k, $s) = split /:/, $txt;
	open FH, "> $file";
	if ($name eq 'aws_access_key_id') {
		print FH "$value:$s";
	} elsif ($name eq 'aws_secret_access_key') {
		print FH "$k:$value"
	}
	
	return 1;
}

sub _remove_did {
	my $did = shift || return;
	return unless $config{api_login} && $config{api_pass};
	
	my $body = get "http://api.vitelity.net/api.php?login=$config{api_login}&pass=$config{api_pass}&cmd=removedid&did=$did";
	warn $body;
	return $body =~ /success/;
}

sub get_livechannels {
	my $channels = `fs_cli -rx "show channels"`;
	my @channels = ();
	
	my $sth = $dbh->prepare("select widgetid from vconnect_widget,v_extensions where vconnect_widget.extension_uid=v_extensions.extension_uuid and user_context='$HOSTNAME' and extension=? limit 1");
	for my $line (split /\n/, $channels) {
		my @f = split ',', $line;
		next unless $f[0] =~ /\-/ || $f[0] =~ /^\d+$/;
		
		$sth -> execute($f[7]);
		my $row = $sth->fetchrow_hashref();
		my $widgetid = $row->{widgetid};
		
		my $ip = $f[8];
		my $type = 1;
		push @channels, "$f[0];$row->{widgetid};$f[8]:$type";
	}	
	
	
	print j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}, livechannels => join(',', @channels)});
}

sub get_channeldetail {
	#uuid,direction,created,created_epoch,name,state,cid_name,cid_num,ip_addr,dest,application,application_data,dialplan,context,read_codec,read_rate,read_bit_rate,write_codec,write_rate,write_bit_rate,secure,hostname,presence_id,presence_data,callstate,callee_name,callee_num,callee_direction,call_uuid,sent_callee_name,sent_callee_num
#d9f255f8-040c-4a49-800d-9fdb1e4e87df,inbound,2014-05-19 23:41:35,1400568095,sofia/internal/100195@vconnect.velantro.net,CS_EXECUTE,100195,100195,140.206.155.127,8882115404,bridge,sofia/gateway/vconnect.velantro.net-a2b/888882115404,XML,vconnect.velantro.net,PCMU,8000,64000,PCMU,8000,64000,srtp:dtls:AES_CM_128_HMAC_SHA1_80,manage1,100195@vconnect.velantro.net,,ACTIVE,Outbound Call,888882115404,SEND,d9f255f8-040c-4a49-800d-9fdb1e4e87df,Outbound Call,888882115404
#231e5597-058b-4516-9573-d7a6a0886bc3,outbound,2014-05-19 23:41:35,1400568095,sofia/external/888882115404,CS_EXCHANGE_MEDIA,8183948767,8183948767,140.206.155.127,888882115404,,,XML,vconnect.velantro.net,PCMU,8000,64000,PCMU,8000,64000,,manage1,,,ACTIVE,Outbound Call,888882115404,SEND,d9f255f8-040c-4a49-800d-9fdb1e4e87df,8183948767,8183948767

	#2 total.
	my $uuid = $query{uuid};
	my $channels = `fs_cli -rx "show channels"`;
	
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
	my $channels = `fs_cli -rx "show channels"`;
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
	
	if (time - $starttime > 240) {
		$memcache->delete($ext_tid);
		exit 0; #force max connection time to 1h
	}
	
	my $status = $memcache->get($ext_tid);
	my $current_state = '';
	
	my $channels = `fs_cli -rx "show channels"`;
	my $cnt      = 0; $i = 0;
	for my $line (split /\n/, $channels) {
		my @f = split ',', $line;
		if ($i++ == 0) {
			if ($line =~ /,accountcode,/) {
				$state_index = 25;
			} else {
				$state_index = 24;
			}
			warn "state_index:$state_index";

		}
		
		if ($f[22] eq $ext && $f[33] ) { #presence_id && initial_ip_addr
			
			$current_state = $f[$state_index];
			if ($status ne $current_state) {		
				print "data:",j({error => '0', 'message' => 'ok', 'actionid' => $query{actionid}, uuid => $f[0],
					 caller => "$f[6] <$f[7]>", start_time => $f[2], current_state => $f[24]}), "\n\n";
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

sub _update_did {
	my ($did, $number) = @_;
	return unless $did && $number;
	my $body = get "http://api.vitelity.net/api.php?login=$config{api_login}&pass=$config{api_pass}&cmd=routesip&did=$did&routesip=$number";
	return $body =~ /success/;
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
