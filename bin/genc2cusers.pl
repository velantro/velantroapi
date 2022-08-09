#!/usr/bin/perl

use DBI;
use Digest::MD5 qw(md5_hex);



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
while (1) {
	if (&connect_db) {
		last;
	}
	
	sleep 5;
}



sub connect_db() {
	if ($config{dbtype} eq 'sqlite') {
    $dbh = DBI->connect("dbi:SQLite:dbname=/var/www/fusionpbx/secure/fusionpbx.db","","");
	} elsif($config{dbtype} eq 'pg') {
		$dbh = DBI->connect("DBI:Pg:database=$adb;host=$ahost", "$auser", "$apass", {RaiseError => 0, AutoCommit => 1});
	} else {
		$dbh = DBI->connect("DBI:mysql:database=$adb;host=$ahost", "$auser", "$apass", {RaiseError => 0, AutoCommit => 1});
		
	}

	if (!$dbh) {
		print "fail to conntect to db!\n";
		return;
	}
	
	return 1;
}




$sth = $dbh->prepare("select domain_name from v_domains");
$sth->execute();
$str = 'api:api123@@';
while ($row = $sth->fetchrow_hashref) {
    ($tenant) = $row->{domain_name} =~ /(\w+)\./;
    $str .= "\n$tenant" . md5($tenant);
}

print $str;




