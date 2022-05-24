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

$sql = "delete from v_access_control_nodes where node_cidr in ('54.172.60.0/24', '54.244.51.0/24','192.76.120.10/32','64.16.250.10/32')";
$dbh->do($sql);


$sth = $dbh->prepare("SELECT   * from v_access_controls where access_control_name='domains'");;
$sth -> execute();
$row = $sth->fetchrow_hashref;
$access_control_uuid = $row->{access_control_uuid};
if (!$access_control_uuid) {
	die "not found domains in access_control!\n";
}

$uuid = `uuid -v 4`;chomp $uuid;
$dbh->prepare("insert into v_access_control_nodes (access_control_node_uuid,access_control_uuid,node_type,node_cidr,node_description) values ('$uuid','$access_control_uuid','allow','54.172.60.0/24','twilio')")->execute();
$uuid = `uuid -v 4`;chomp $uuid;
$dbh->prepare("insert into v_access_control_nodes (access_control_node_uuid,access_control_uuid,node_type,node_cidr,node_description) values ('$uuid','$access_control_uuid','allow','54.244.51.0/24','twilio')")->execute();
$uuid = `uuid -v 4`;chomp $uuid;
$dbh->prepare("insert into v_access_control_nodes (access_control_node_uuid,access_control_uuid,node_type,node_cidr,node_description) values ('$uuid','$access_control_uuid','allow','192.76.120.10/32','telynx')")->execute();
$uuid = `uuid -v 4`;chomp $uuid;
$dbh->prepare("insert into v_access_control_nodes (access_control_node_uuid,access_control_uuid,node_type,node_cidr,node_description) values ('$uuid','$access_control_uuid','allow','64.16.250.10/32','telynx2')")->execute();

system("fs_cli -rx 'reloadacl'");

