#!/usr/bin/perl
use DBI;



my $txt = `cat /etc/fb.conf`;
    
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
&connect_db();

sub connect_db() {
	if ($config{dbtype} eq 'sqlite') {
    $dbh = DBI->connect("dbi:SQLite:dbname=/var/www/fusionpbx/secure/fusionpbx.db","","");
	} elsif($config{dbtype} eq 'pg') {
		$dbh = DBI->connect("DBI:Pg:database=$adb;host=$ahost", "$auser", "$apass", {RaiseError => 0, AutoCommit => 1});
	} else {
		$dbh = DBI->connect("DBI:mysql:database=$adb;host=$ahost", "$auser", "$apass", {RaiseError => 0, AutoCommit => 1});
		
	}

	if (!$dbh) {
			die  'internal error: fail to login db';
	}
}

$domain_name = shift || die "No Domain Name";
$sth = $dbh->prepare("SELECT   domain_uuid,domain_name from v_domains where domain_name != ?");
$sth -> execute($domain_name);
while($row = $sth->fetchrow_hashref) {
	next unless $row->{domain_name} =~ /velantro.net$/;
	
	warn "start delete " . $row->{domain_name} . " = " .  $row->{domain_uuid} . "!\n";
	system("perl /var/www/api/bin/remove_domain.pl " . $row->{domain_name})
}


