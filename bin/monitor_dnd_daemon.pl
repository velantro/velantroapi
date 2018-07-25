use DBI;
$out = `ps aux | grep $0 | grep -v 'grep ' | wc -l`;
chomp $out;
$debug = shift;
if ($out > 1) {
    warn "another $0 is already running, quit! ...";
    exit 0;
}
my %config = ();
my $txt = `cat /etc/fb.conf`;

for (split /\n/, $txt) {
    my ($key, $val)     = split /=/, $_, 2;

    if ($key) {
        $config{$key} = $val;
        warn "$key=$val\n";
    }
}





sub connect_db() {
    local ($type, $adb, $ahost, $auser, $apass) = @_;
    $type  ||= $config{dbtype};
    $adb   ||= $config{dbname};
    $ahost ||= $config{dbhost};
    $auser ||= $config{dbuser};
    $apass ||= $config{dbpass};
    local $dbh;
	if ($type eq 'sqlite') {
    $dbh = DBI->connect("dbi:SQLite:dbname=$adb","","");
	} elsif($type eq 'pg') {
		$dbh = DBI->connect("DBI:Pg:database=$adb;host=$ahost", "$auser", "$apass", {RaiseError => 0, AutoCommit => 1});
	} else {
		$dbh = DBI->connect("DBI:mysql:database=$adb;host=$ahost", "$auser", "$apass", {RaiseError => 0, AutoCommit => 1});
		
	}

	if (!$dbh) {
        print 'internal error: fail to login db';
        exit 0;
	}
    
    return $dbh;
}

$i = 1;
%last_ext_agent = ();

if (-e '/usr/local/freeswitch/db/callcenter.db') {
    $db = '/usr/local/freeswitch/db/callcenter.db'
} elsif (-e '/var/lib/freeswitch/db/callcenter.db') {
    $db = '/var/lib/freeswitch/db/callcenter.db';
} else {
    die "No callcenter.db found!\n";
}

$dbh = &connect_db('sqlite', $db);
$dbh_main = &connect_db();
while (1) {
    if ($debug) {
        print "$i: \n";
    }
	my $txt = `cat /etc/fb.conf`;

	my %config = ();
	for (split /\n/, $txt) {
	    my ($key, $val)     = split /=/, $_, 2;

	    if ($key) {
	        $config{$key} = $val;
	        #warn "$key=$val\n";
	    }
	}
	
    local $switch_cmd = 'show channels';
    warn &now() . ": " , $switch_cmd;
    local $event_socket_str = `fs_cli -rx "$switch_cmd"`;
    local $result2 = &str_to_named_array($event_socket_str, ',');
    

    local %ext_agent = &get_extension_agent_hash();
    local %tmp = ();
    for $row2 (@$result2 ) {
        $presence_id = $row2->{presence_id}; next unless $presence_id;
        warn "check $presence_id " . $ext_agent{$presence_id}{name} . " " . $ext_agent{$presence_id}{state};

        next unless $ext_agent{$presence_id};
        next unless $ext_agent{$presence_id}{state} eq 'Waiting' or $ext_agent{$presence_id}{state} eq 'In a queue call';
        
        $agent_name = $ext_agent{$presence_id}{name};
        if ($ext_agent{$presence_id}{state} eq 'Waiting') {
            
            #$cmd = "fs_cli -rx \"callcenter_config agent set state $agent_name 'In a queue call'\"";
            #warn &now() . ": $cmd";
            
            $res = &do_update_agent_status($agent_name, 'In a queue call');
            #$res = `$cmd`;
        }
        
        $tmp{$presence_id} = $ext_agent{$presence_id};
    }
    
    for $presence_id (keys %last_ext_agent) {
        if (!$tmp{$presence_id}) {
            $agent_name = $last_ext_agent{$presence_id}{name};
            #$cmd = "fs_cli -rx \"callcenter_config agent set state $agent_name 'Waiting'\"";
            warn &now() . ": $cmd";
            
            $res = &do_update_agent_status($agent_name, 'Waiting');

            #$res = `$cmd`;
        }      
    }
    %last_ext_agent = %tmp;
    
    $timeout = $config{dnd_timeout} || 5;
    sleep $timeout;
}

$dbh->disconnect();

sub str_to_named_array () {
	local ($tmp_str, $tmp_delimiter) = @_;
	
	@tmp_array = split ("\n", $tmp_str);
	@result = ();
	if (&trim(uc($tmp_array[0])) ne "+OK") {
		@tmp_field_name_array = split ($tmp_delimiter, $tmp_array[0]);
		$x = 0;
		for $row (@tmp_array) {
			if ($x > 0) {
				@tmp_field_value_array = split ($tmp_delimiter, $tmp_array[$x]);
				$y = 0;
				for $tmp_value (@tmp_field_value_array) {
					$tmp_name = $tmp_field_name_array[$y];
					if (&trim(uc($tmp_value)) ne "+OK") {
						$result[$x]->{$tmp_name} = $tmp_value;
					}
					$y++;
				}
			}
			$x++;
		}
	}
	return \@result;
}

sub trim {
     my @out = @_;
     for (@out) {
         s/^\s+//;
         s/\s+$//;
     }
     return wantarray ? @out : $out[0];
}

sub now() {
    @v = localtime;
    return sprintf("%04d-%02d-%02d %02d:%02d:%02d", 1900+$v[5],$v[4]+1,$v[3],$v[2],$v[1],$v[0]);
}

sub get_extension_agent_hash() {
    local $sth = $dbh->prepare("select contact,name,status,state from agents");
    $sth->execute();
    local %hash = ();

    while ($row = $sth->fetchrow_hashref) {
        #warn $row->{contact}, $row->{name}, $row->{state};
        local ($ext) = $row->{contact} =~ m{user/(.+)$};
        $hash{$ext}{name} = $row->{name};
        $hash{$ext}{status} = $row->{status};
        $hash{$ext}{state} = $row->{state};        
    }
    
    return %hash;
}

sub do_update_agent_status() {
    local ($agent_name, $state) = @_;
    ($name, $domain_name) = split '@', $agent_name;
    local $sql = "SELECT domain_setting_value FROM v_domain_settings left join v_domains on v_domain_settings.domain_uuid=v_domains.domain_uuid where domain_name = '$domain_name' and domain_setting_category='agent' and domain_setting_subcategory='skip_busy_agent' and domain_setting_enabled='true' limit 1";
    
    local $sth = $dbh_main->prepare($sql);
    $sth->execute();
    $res = $sth->fetchrow_hashref;
    
    if ($res->{domain_setting_value} ne 'true') {        
        warn "skip_busy_aent:$domain_name not enabled, ignored!!!\n";
        return;
    }  
    
    $cmd = "fs_cli -rx \"callcenter_config agent set state $agent_name '$state'\"";
    warn &now() . ": $cmd";
    
    $res = `$cmd`;
     
    return $res;
}
