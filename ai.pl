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
$CGI::Simple::POST_MAX = 10_048_576;

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

if ($cgi->request_method eq 'GET') {
	$query_string = uri_unescape($cgi->query_string());
	for (split /&|&&/, $query_string) {
		#warn $_;
		($var, $val) = split '=', $_, 2;
		$query{$var} = $val;
		
		#warn "$var ==> $val";
	}
} else {
	for my $key ($cgi->url_param) {
		$query{$key} = $cgi->url_param($key);
		warn "POST $key ==> "  . $cgi->url_param($key);
	}
	for my $key ($cgi->param) {
		$query{$key} = $cgi->param($key);
		#warn "POST $key ==> "  . $cgi->param($key);
	}
}


my $dbh = '';
$config{dbtype} = 'pg';
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

print $cgi->header();

$action = $query{action};
if ($action eq 'listagents') {
	$account = $query{account};
	$output = `CLOUDSDK_CONFIG=/var/www/google/$account /var/www/google-cloud-sdk/bin/gcloud --format=json projects list`;
	
	print $output;
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


sub clean_str() {
  #limpa tudo que nao for letras e numeros
  local ($old,$extra1,$extra2)=@_;
  local ($new,$extra,$i);
  $old=$old."";
  $new="";
  $caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-_.".$extra1; 		# new default
  $caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-_. @".$extra1; 	# using old default to be compatible with old cgi
  if ($extra1 eq "MINIMAL") {$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890".$extra2;}
  if ($extra2 eq "MINIMAL") {$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890".$extra1;}
  if ($extra1 eq "URL") 	{$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\%".$extra2;}
  if ($extra2 eq "URL") 	{$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\%".$extra1;}
  if ($extra1 eq "SQLSAFE") {$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\% ".$extra2;}
  if ($extra2 eq "SQLSAFE") {$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\% ".$extra1;}
  if ($extra1 eq "TEXT") 	{$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\% ".$extra2;}
  if ($extra2 eq "TEXT") 	{$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\% ".$extra1;}
  if ($extra1 eq "PASSWORD"){$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\%".$extra2;}
  if ($extra2 eq "PASSWORD"){$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\%".$extra1;}
  if ($extra1 eq "EMAIL")	{$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\%".$extra2;}
  if ($extra2 eq "EMAIL")	{$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\%".$extra1;}
  for ($i=0;$i<length($old);$i++) {if (index($caracterok,substr($old,$i,1))>-1) {$new=$new.substr($old,$i,1);} }
  if ($extra1 eq "SQLSAFE") { $new= &clean_str_helper($new) }
  if ($extra2 eq "SQLSAFE") { $new= &clean_str_helper($new) }
  return $new;
}

sub clean_str_helper{
	my $string = @_[0];
	$string =~ s/\\/\\\\/g ; # first escape all backslashes or they disappear
	$string =~ s/\n/\\n/g ; # escape new line chars
	$string =~ s/\r//g ; # escape carriage returns
	$string =~ s/\'/\\\'/g; # escape single quotes
	$string =~ s/\"/\\\"/g; # escape double quotes
	return $string ;
}



sub get_bchannel_uuid() {
	local $uuid = shift || return;
	%raw_calls = &parse_calls();
	for (keys %raw_calls) {
		if ($_ eq $uuid) {
			return $raw_calls{$_}{b_uuid};
			last;
		}
	}
	
	return;
}

sub parse_calls () {
	local $header_csv = 'uuid,direction,created,created_epoch,name,state,cid_name,cid_num,ip_addr,dest,presence_id,presence_data,callstate,callee_name,callee_num,callee_direction,call_uuid,hostname,sent_callee_name,sent_callee_num,b_uuid,b_direction,b_created,b_created_epoch,b_name,b_state,b_cid_name,b_cid_num,b_ip_addr,b_dest,b_presence_id,b_presence_data,b_callstate,b_callee_name,b_callee_num,b_callee_direction,b_sent_callee_name,b_sent_callee_num,call_created_epoch';
	
	@header_array = split /,/, $header_csv;
	
	%calls = ();
	$output = &runswitchcommand('internal', 'show calls');
	for (split /\n/, $output) {
		next if /^\s*$/;
		@v = split /,/, $_;
		
		for (0..$#header_array) {
			$calls{$v[0]}{$header_array[$_]} = $v[$_];
		}
	}
	
	return %calls;	
}

sub runswitchcommand {
	$internal = shift;
	$cmd = shift || return '';
	
	$res = `fs_cli -x "$cmd"`;
	return $res;
}
