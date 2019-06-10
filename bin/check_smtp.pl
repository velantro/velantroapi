use Net::SMTP;
use DBI;

my $txt = `cat /etc/fb.conf`;
    
my %config = ();
for (split /\n/, $txt) {
    my ($key, $val)	= split /=/, $_, 2;
    
    if ($key) {
        $config{$key} = $val;
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

$sth = $dbh->prepare("SELECT * FROM v_default_settings WHERE default_setting_category = 'email'");
$sth -> execute($domain_name);
while($row = $sth->fetchrow_hashref) {
    $config{$row->{default_setting_subcategory}} = $row->{default_setting_value};    
}


$host = $config{smtp_host};
$smtp = Net::SMTP->new($host ,
                       Hello => $host,
                       Timeout => 30,
                       Debug   => 1,
                      );
$user = $config{smtp_username};
$pass = $config{smtp_password};
$to ='zhongxiang721@163.com';
$smtp->auth($user, $pass);
$smtp->mail($config{smtp_from});
$smtp->recipient($to);
$data =<<D;
from:$config{smtp_from}
to: $to
Subject: smtp test
MIME-Version: 1.0
Content-Type: text/html;

hell smtp server running fine!
<a href='#'>here</a>

D

$smtp->data($data);

$smtp->quit;
