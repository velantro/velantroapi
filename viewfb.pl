#!/usr/bin/perl
use CGI::Simple;
$CGI::Simple::DISABLE_UPLOADS = 0;
$CGI::Simple::POST_MAX = 1_000_000_000;
use URI::Escape;
#use utf8;
use File::Tail; #apt-get install libfile-tail-perl
use DBI;

$out = `ps aux | grep $0 | grep -v 'grep ' | wc -l`;
chomp $out;

if ($out > 1) {
    warn "another $0 is already running, quit! ...";
    exit 0;
}

my $now_file = "/tmp/fail2ban_now.log";
my $lock_file = '/tmp/fail2ban_restart.lock';

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
    
my $pid = fork;
if ($pid <= 0) {
    warn "p1 start..";
    while (1) {
        
        if (-e $lock_file) {
            $cmd = `cat $lock_file`;
            if ($cmd eq 'restart') {
                restart();
            } elsif ($cmd eq 'start') {
                restart('start');
            } elsif ($cmd eq 'stop') {
                restart('stop');
            }
            
            unlink $lock_file;
        }
        
        sleep 1;
    }
    exit 0;
}

my $pid2 = fork;
if ($pid2 <= 0) {
    warn "p2 start ..";
    while (1) {
        check_fraud_calls();
        sleep 300;        
    }
    exit 0;
}

system ("rm -f $now_file; touch $now_file");

my $file = File::Tail->new(name => "/var/log/fail2ban.log", interval => 2);

system ("/etc/init.d/fail2ban restart");

while (defined($line = $file->read)) {
    #warn $line, "\n";
    #2014-10-27 19:36:47,003 fail2ban.actions: WARNING [freeswitch-tcp] Ban 71.95.176.58
    if ($line =~ /^(\d\d\d\d\-\d\d\-\d\d \d\d:\d\d:\d\d,\d+) fail2ban\.actions: WARNING \[(.+?)\] (\w+) (.+)$/) {
        my ($t, $f, $a, $i) = ($1, $2, $3, $4);
        warn "[$t] $a $i for $f ...\n";
        
        if ($a eq 'Ban') {
            my $ext = '';
            if  ($f eq 'freeswitch-udp' || $f eq 'freeswitch-tcp') {
                open L, '/usr/local/freeswitch/log/freeswitch.log';
                @lines = <L>;
                
                for (reverse @lines) {
                    if (/SIP auth failure \(REGISTER\) on sofia profile 'internal' for \[(.+?)\] from ip $i/) {
                        warn "found $1 register error from $i...";
                        $ext = $1;
                        last;
                    }
                }
                #insert into fail2ban now_ban (timestr,filter,action,ip,data)
            }
            addentry("$t;$f;$a;$i;$ext");
        } elsif ($a eq 'Unban') {
            delentry('ip', $i);
        }       
    }
}


sub restart {
    my $mode = shift || 'restart';
    
    warn "$mode fail2ban and empty $now_file";
    system("/etc/init.d/fail2ban $mode");
    open W, "> $now_file";
    print W '';
    close W;
}

sub addentry {
    my $line = shift;
    open A, ">> $now_file";
    
    print A $line, "\n";
    close A;
}


sub delentry {
    my ($w, $ip) = @_;
    my $i = 3;
    if ($w eq 'ip') {
        $i = 3;
    }
    
    open R, "$now_file";
    
    my $raw = '';
    
    while (<R>) {
        my @f = split ';';
        $raw .= $_ unless $f[$i] eq $ip;
    }
    
    close R;
    
    open W, "> $now_file";
    print W $raw;
    close W;
}


sub check_fraud_calls {
    $sth = $dbh->prepare("select now() now,remote_media_ip,destination_number,start_stamp from v_xml_cdr
                         where start_epoch > ? and context='public' and length(destination_number) > 11");
    $sth->execute(time-300);
    
    
    %spool = ();
    open W, ">> /usr/local/freeswitch/log/fraud.log";
    while ($row = $sth->fetchrow_hashref) {
        print W "$row->{now} find fraud calls from ip $row->{remote_media_ip}\n";
    }
    
    close W;
}

