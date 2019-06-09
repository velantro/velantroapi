#!/usr/bin/perl
use DBI;

#$date = shift;

if (!$date) {
	@v = localtime();
	$date = sprintf("%04d-%02d-%02d", 1900+$v[5],$v[4]+1,$v[3]);
}
warn "Export Domain  on date: $date!\n";
$start = "$date 00:00:00";
$end	 = "$date 23:59:59";

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
$sth = $dbh->prepare("SELECT   domain_uuid from v_domains where domain_name=?");
$sth -> execute($domain_name);
$row = $sth->fetchrow_hashref;
$domain_uuid = $row->{domain_uuid} || die "$domain_name not found on this server!";
warn "start delete $domain_name ($domain_uuid)!\n";


$sth = $dbh->prepare("SELECT   tablename   FROM   pg_tables    
											WHERE   tablename   NOT   LIKE   'pg%'    
											AND tablename NOT LIKE 'sql_%'  
											ORDER   BY   tablename ");


$sth->execute();

$sth_table = $dbh->prepare("SELECT col_description(a.attrelid,a.attnum) as comment,format_type(a.atttypid,a.atttypmod) as type,
														a.attname as name, a.attnotnull as notnull FROM pg_class as c,pg_attribute as a  
														where c.relname = ? and a.attrelid = c.oid and a.attnum>0 and  a.attname='domain_uuid' ");
														
while ($row = $sth->fetchrow_hashref) {
	$table = $row->{tablename};
	print "check $table ..";
	
	$sth_table->execute($table);
	$table_col = $sth_table->fetchrow_hashref;
	
	if ($table_col&&$table_col->{name}) {
		#next if $table eq 'v_xml_cdr' or $table eq 'v_xml_cdr_simple';
		print " OK!\n";
		#push @backup_tables, $table;
		$cmd = "psql fusionpbx  -U fusionpbx   -h 127.0.0.1 -c \"delete from $table where domain_uuid='$domain_uuid'\"";
		print "$cmd\n";
		
		system($cmd);
	} else {
		print "FAIL!\n";
	}
}


system("rm -rf /usr/local/freeswitch/recordings/$domain_name");
system("rm -rf /usr/local/freeswitch/sounds/music/$domain_name");
system("rm -rf /usr/local/freeswitch/storage/voicemail/default/$domain_name");

system("rm -rf /tmp/$domain_name");
system("fs_cli -rx 'memcache flush'");
warn "delete $domain_name, DONE!\n";