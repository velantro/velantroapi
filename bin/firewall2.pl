adjust_iptable_from_url('blackip', 'view', 0);
adjust_iptable_from_url('allowedip', 'viewallowedip', 1);

sub adjust_iptable_from_url {
	my ($name, $url_action, $accept) = @_;
    adjust_iptable($name,  $accept, "curl -k \"http://vip.velantro.net/app/exec/blackip.php?action=$url_action\"");
}

sub adjust_iptable {
	my ($name, $accept, $load_new_rules) = @_;
    
    my $rule_file_name = "/tmp/$name.txt";
    my $lck_file_name = "/tmp/$name.lck";
    
    my $last_rule_file = `cat $rule_file_name`;
	my $new_rule_file = `$load_new_rules`;

	if (-e $lck_file_name) {
        warn "$lck_file_name found, exit!\n";
        return;
    }

    system("touch $lck_file_name");

    if (!$new_rule_file) {
        warn "new rule is null, quit!\n"; 
        unlink $lck_file_name;
        return;
    }

    if ($last_rule_file eq $new_rule_file) {
        warn "firewall rule not changed!\n";
        unlink $lck_file_name;
        return;
    }
    
 	my %last_rules = ();
    my %new_rules = ();

    for (split /\n/, $last_rule_file) {
        chomp; s/[\r\n]//;

        $last_rules{$_} = 1;
    }

    for (split /\n/, $new_rule_file) {
        chomp; s/[\r\n]//;
        my $ip = $_;

        if (is_not_in_any_rules($ip, \%last_rules, \%new_rules)){
            $new_rules{$ip} = 1;  

            add_iptables_rule($ip, 1, $accept);
        }

        delete $last_rules{$ip};
    }

    for $ip (keys %last_rules) {
        add_iptables_rule($ip, 0, $accept);
    }

	write_new_rule_file($rule_file_name, $new_rule_file);
	unlink $lck_file_name;
}

sub write_new_rule_file {
    my ($file_name, $new_rules) = @_;
    open W, "> $file_name";
    print W $new_rules;
    close W;
}

sub is_not_in_any_rules {
    my ($val, $last_rules, $new_rules) = @_;	
    return !($$last_rules{$val} || $$new_rules{$val});
}

sub add_iptables_rule {
    my ($ip, $add, $is_accept) = @_;
    my $action = $is_accept ? "ACCEPT" : "DROP";
    my $add_or_remove = $add ? "I" : "D";
	
    system ("iptables -$add_or_remove INPUT -s $ip -j $action");
}