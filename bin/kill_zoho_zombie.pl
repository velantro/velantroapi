#!/usr/bin/perl
#======================================================
# load head
#======================================================
use IO::Socket;
#use Switch;
use Data::Dumper;
use DBI;
use Time::Local;
#use Math::Round qw(:all);
use URI::Escape;
#use Net::AMQP::RabbitMQ;
use POSIX qw(strftime);
use MIME::Base64;
require "/var/www/c2capi/bin/default.include.pl";
$ext = shift;
&refresh_zoho_tokens();
$sql = "select ext,data from v_zoho_api_cache where " . ($ext ? ' 1=1 ' : "ext='$ext' ");
warn $sql;
%cache = &database_select_as_hash($sql, "data");
for $key (keys %cache) {
	$now = &now();
	$data = $data{$key}{data} . "state=ended&start_time=$now&duration=0";
	warn $data;
	&send_zoho_request('callnotify', $ext, $data);
	&database_do("delete from v_zoho_api_cache where ext='$key'");
}

sub refresh_zoho_tokens() {
	%zoho_tokens = &database_select_as_hash("select ext,zohouser,refresh_token,access_token,extract(epoch from update_date) from v_zoho_users where ext is not null", "zohouser,refresh_token,access_token,update_time");
	for $key(keys %zoho_tokens) {

		if (time-$zoho_tokens{$key}{update_time} > 1800) {
			$client_id = '1000.Z7AE3OOFNGE5Y3IJPZGJWK45QWTM0D';
			$client_secret = '9d6bb961106e7e495928b13f6bec05e56c1cbba6dc';
			$refresh_token = $zoho_tokens{$key}{refresh_token};
			$out = `curl -k 'https://accounts.zoho.com/oauth/v2/token' -X POST -d 'refresh_token=$refresh_token&client_id=$client_id&client_secret=$client_secret&grant_type=refresh_token'`;
			%h = &Json2Hash($out);
			if ($h{access_token}) {
				$zoho_tokens{$key}{access_token} = $h{access_token};
				$sql =  "update v_zoho_users set access_token='" . $h{access_token} . "',update_date=now()";
				warn "sql: $sql\n";
				&database_do($sql);
			}
			
			break;
		}
		
	}
}

sub send_zoho_request() {
	local ($type, $ext, $data) = @_;
	if ($type eq 'callnotify') {
		$url = 'https://www.zohoapis.com/phonebridge/v3/callnotify';
	}
	warn "$type, $ext, $data";
	$code = $zoho_tokens{$ext}{access_token};
	$cmd = "curl  $url -X POST -d '$data' -H 'Authorization: Zoho-oauthtoken $code' -H 'Content-Type: application/x-www-form-urlencoded'";
	$res = `$cmd`;
	log_debug("cmd:$cmd\nresponse: $res\n");
	return $res;
}

sub log_debug() {
	$msg = shift;
	$t = getTime();
	print STDERR "$t $msg\n";
}


sub log_sql() {
	$msg = shift;
	$t = getTime();
	open "W", ">> /tmp/log.sql";
	print W "$msg\n";
	close W;
}
#======================================================
# john library
#======================================================
sub command {
        my $cmd = @_[0];
        my $buf="";
        print $remote $cmd;
       return $buf; 
}
sub getTime {
	@months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	@weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
	($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
	$year = 1900 + $yearOffset;
	if ($hour < 10) {
		$hour = "0$hour";
	}
	if ($minute < 10) {
		$minute = "0$minute";
	}
	if ($second < 10) {
		$second = "0$second";
	}
	$theTime = "[$months[$month] $dayOfMonth $hour:$minute:$second]";
	return $theTime; 
}

sub date {
	$mode = shift;
	($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
	
	if ($mode eq 't') {
		return sprintf("%02d:%02d:%02d", $hour, $minute, $second);
	} elsif ($mode eq 'd') {
		return sprintf("%d/%d/%d", $month+1, $dayOfMonth, $yearOffset+1900);
	}
}

sub now {
	$mode = shift;
	($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
	
	return  sprintf("%04d-%02d-%02d %02d:%02d:%02d", $yearOffset+1900, $month+1, $dayOfMonth,  $hour, $minute, $second);
}
sub login_cmd {
        my $cmd = @_[0];
        my $buf="";
        print $remote $cmd;
        return $buf;
}
sub DELETE_trim($) {                                   
        my $string = shift;                     
        $string =~ s/^\s+//;                    
        $string =~ s/\s+$//;            
        return $string;                         
}                                               
sub ltrim($)                             
{                                
        my $string = shift;
        $string =~ s/^\s+//;
        return $string;
}       
sub rtrim($)
{               
        my $string = shift;
        $string =~ s/\s+$//;
        return $string;
}
sub trim {
     my @out = @_;
     for (@out) {
         s/^\s+//;
         s/\s+$//;
     }
     return wantarray ? @out : $out[0];
}

sub asterisk_debug_print(){
	local($msg) = @_;
	print STDERR "$msg \n";
	
}
#======================================================
 
