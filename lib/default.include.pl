#!/usr/bin/perl
=pod
	Version 1.0
	Developed by Velantro inc
	Contributor(s):
	George Gabrielyan <george@velantro.com>
=cut


################################################################################

################################################################################
$|=1;$!=1; # disable buffer 
#
# include perl modules and some variables
use File::Copy;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use LWP 5.69;
use Logger::Syslog;
use Data::Dumper;
use Digest::MD5  qw(md5 md5_hex md5_base64);
use POSIX qw(mkfifo);
use LWP;
use HTTP::Request::Common;
use LWP::UserAgent;
use HTTP::Cookies;
#use HTTP::Date;
use JSON;

#
# start app config
%app	 	= ();
%sys		= ();
%arg		= ();
%call		= ();
$memory_garbage_collector_last_check = 0;
$memory = ();
$app{debug_switch}	= 1;
$global_useragent   = null;

return 1;

sub default_include_init(){
	open(IN,"/etc/pbx-v2.cfg"); while (<IN>) { chomp($_); ($tmp1,$tmp2) = split(/\=/,$_,2); $app{&trim("\L$tmp1")}=$tmp2; } close(IN);
	$app{app_root}			= $app{app_root} || "/usr/local/pbx-v2/";
	##$app{host_name}			= $app{host_name} || "dev-desktop";# we need remove all calls to this variable. we need use server_id instead
	$app{server_id}			= $app{server_id} || "1";
	$app{database_dsn}		= $app{database_dsn} || "DBI:Pg:database=fusionpbx;host=127.0.0.1";
	$app{database_user}		= $app{database_user} || "fusionpbx";
	$app{database_password}	= $app{database_password} || "fusionpbx";
	$host_name				= $app{host_name};
	$app{pbx_host}		= $app{pbx_host}     || '';
	$app{pbx_hostname}	= $app{pbx_hostname} || '';
	$app{base_domain}	= $app{base_domain}	 || '';
	$app{log_level}		= $app{log_level} 	 || 4;
	$app{log_file}		= '/tmp/pbx.log';
	
	warn Dumper(\%app);
	open LOG, ">> $app{log_file}";

}
################################################################################



sub default_ua_init() {
	$global_useragent  = LWP::UserAgent->new('agent' => "Salzh PBX");
	$file = '/tmp/cookie-' . $app{user_id} . '.txt';
	
	warn "set cookie to $file";
	$jar = HTTP::Cookies->new(
		file => "$file",
		autosave => 1,
	);

	$global_headers{Cookie} = $app{pbx_cookie};
	return 1;
}

sub default_ua_init2() {
	$global_useragent  = LWP::UserAgent->new('agent' => "Salzh PBX");	
	return 1;
}


sub do_pbx_login_check() {
	$check_url = "http://$app{pbx_host}/app/edit/index.php?dir=xml";
	warn "$check_url: Cookie: $app{pbx_cookie}";
	$res = $global_useragent->request(GET $check_url, %global_headers);
	#warn Dumper($res);
	$url = $res->request->uri();
	warn $url;
	if ($url =~ /login\.php/) {
		warn "$_: PBX login is expired!\n";
		return;
	} else {
		return 1;
	}
}

sub do_pbx_login() {
	local($user, $pwd, $domain) = @_;
	$cookie_id = time . int(rand 9999);
	
	$file = "/tmp/cookie-$cookie_id" . '.txt';
	warn "set cookie to $file";
	$jar = HTTP::Cookies->new(
		file => "$file",
		autosave => 1,
	);

	$is_login = 0;
	for (1..3) {
			
		$loginurl = "http://$domain/core/user_settings/user_dashboard.php";
					#"username=$user&&password=$pwd";
		
		$res   =  $global_useragent->request(POST $loginurl, Content => ['username' => $user, 'password' => $pwd]);
		#$html = `curl -s -k -c $file "$loginurl"`;
		$location = $res->header('Location');
		warn "new location: $location\n";
		if ($location =~ /login.php/) {
			warn "$_: LOGIN PBX FAIL: $loginurl!\n";
		} else {
			$is_login = 1;
			warn "$_: login PBX OK!\n";
			$set_cookie = $res->header('Set-Cookie');
			warn $set_cookie;
			last;
		}
	}
	if ($is_login) {
			return ('stat' => 'ok', cookie_id => $cookie_id, cookie => $set_cookie);
	} else {
			return ('stat' => 'fail', message => &_('authen fail'));
	}
}


sub default_log_init () {	
}

sub log_debug () {
	($level, $body) = @_;

	%out = &get_today();
	$now = $out{DATE_ID}.$out{TIME_ID};
	
	if ($app{log_level} && $level <= $app{log_level}) {
		print LOG "[$level][$now] - $body";
		warn $body;
	}
}

sub post_data () {
	local %data = @_;
	if ($data{domain_uuid} ||  $data{domain_name} ) {
		$s = &change_domain($data{domain_uuid}, $data{domain_name});
		if (!$s) {
			&log_debug(4, "Error: fail to change to $data{domain}|$data{domain_uuid}!\n");
			return;
		}
	}
	$url = "http://$app{pbx_host}" . $data{urlpath};
	#warn $url;
	#warn @{$data{data}};
	if (@{$data{data}}) {
		$result = $global_useragent -> request(
			POST $url,
			%global_headers,
			Content => $data{data}
		);
	} else {
		$result = $global_useragent -> request(
			GET $url,
			%global_headers
		);
	}
	
	if ($data{reload}) {
		$global_useragent -> request(
			POST $url,
			%global_headers,
			Content => []
		);	
	}
	
	return $result;
}

sub get_data () {
	local %data = @_;
	if ($data{domain_uuid} ||  $data{domain_name} ) {
		$s = &change_domain($data{domain_uuid}, $data{domain_name});
		if (!$s) {
			&log_debug(4, "Error: fail to change to $data{domain}|$data{domain_uuid}!\n");
			return;
		}
	}
	
	$url = "http://$app{pbx_host}" . $data{urlpath};
	
	$result = $global_useragent -> request(
		GET $url,
		%global_headers,
		Content => $data{data}
	);
	
	if ($data{reload}) {
		$global_useragent -> request(
			GET $url,
			%global_headers,
			Content => []
		);	
	}
	
	return $result;
}

sub change_domain () {
	local ($uuid, $name) = @_;
	if (!$uuid) {
		$domain = $name . $app{base_domain} ? ".$app{base_domain}" : '';
		
		%hash = &database_select_as_hash("select 1,domain_uuid from v_domains where domain_name='$domain'", "uuid");
		if (!$hash{1}{uuid}) {
			return;
		}
		$uuid = $hash{1}{uuid};
		
	}
	
	return 1 if !&check_domain_change($uuid); #no need change again
	
	&post_data ('urlpath' => "/core/domain_settings/domains.php?domain_uuid=$uuid&domain_change=true",
		'data' => ['domain_uuid' => $uuid, domain_change => 'true']
		);
	return 1;
}

sub get_domain () {
	local $uuid = &clean_str(substr($form{domain_uuid},0,50),"MINIMAL","_-.");
	local $name = &clean_str(substr($form{domain_name},0,50),"MINIMAL","_-.");
	$name ||= $app{pbx_host};
	%output = ();
	if (!$uuid) {
		$domain = $name . ($app{base_domain} ? ".$app{base_domain}" : '');
		
		%hash = &database_select_as_hash("select 1,domain_uuid,domain_name from v_domains where domain_name='$domain'", "uuid,name");
	} else {
		%hash =  &database_select_as_hash("select 1,domain_uuid,domain_name from v_domains where domain_uuid='$uuid'", "uuid,name");
	}
	
	$output{uuid} = $hash{1}{uuid};
	$output{name} = $hash{1}{name};
	
	return %output;	
}

sub get_config () {
	$key = shift;
	return defined $app{$key} ? $app{$key} : '';
}

#======================================================
# memory 
#======================================================
sub memory_garbage_collector() {
	my ($id,$subsystem);
	$memory_garbage_collector_last_check += 0;
	if ( (time-$memory_garbage_collector_last_check) > (60*60) ) {
		$memory_garbage_collector_last_check = time;
		foreach $subsystem (keys %memory) {
			foreach $id (keys %{$memory{$subsystem}}){
				if (exists($memory{$subsystem}{$id}{time})){
					if ( (time-$memory{$subsystem}{$id}{time}) > (60*60*6) ) {
						delete($memory{$subsystem}{$id})
					}
				}
			}
		}
	}
}
#======================================================


#------------------------
# generic data persistence (get/set values in data table) + system wide config storage
#------------------------
sub data_get(){
	# get clean and reject 
	local($table,$target,$name) = @_;
	$table	= &clean_str(substr($table,0,250),	"._-","MINIMAL");
	$target	= &clean_str(substr($target,0,250),	"._-","MINIMAL");
	$name	= &clean_str(substr($name,0,250),	"._-","MINIMAL");
	if ($table eq "") {return ""}
	# start work
	local ($value,$tmp1,$tmp2);
	$value = "";
	foreach ( &database_select_as_array("select value from $table where $table.group='$target' and name='$name'") ) {$value .= $_;}
	# todo: wtf is this?
	$tmp1="<>"; $tmp2="\n"; $value =~ s/$tmp1/$tmp2/eg;
	# return
	return $value;
}
sub data_get_names(){
	local($table,$target) = @_;
	$table	= &clean_str(substr($table,0,250),	"._-","MINIMAL");
	$target	= &clean_str(substr($target,0,250),	"._-","MINIMAL");
	if ($table eq "") {return ""}
	return &database_select_as_array("select name from $table where $table.group='$target' ");
}
sub data_set(){
	local($table,$target,$name,$value) = @_;
	$table	= &clean_str(substr($table,0,250),	"._-,","MINIMAL");
	$target	= &clean_str(substr($target,0,250),	"._-,","MINIMAL");
	$name	= &clean_str(substr($name,0,250),	"._-,","MINIMAL");
	$value	= &database_escape(&clean_str(substr($value,0,250),	" ._,-&@()*[]=%<>\$/?","MINIMAL"));
	if ($table eq "") {return ""}
	&database_do("delete from $table where $table.group='$target' and name='$name'");
	&database_do("insert into $table ($table.group,name,value) values ('$target','$name','$value') ");
}
sub data_delete(){
	local($table,$target,$name) = @_;
	$table	= &clean_str(substr($table,0,250),	"._-","MINIMAL");
	$target	= &clean_str(substr($target,0,250),	"._-","MINIMAL");
	$name	= &clean_str(substr($name,0,250),	"._-","MINIMAL");
	if ($table eq "") {return ""}
	&database_do("delete from $table where $table.group='$target' and name='$name'");
}
sub system_config_get(){
	local($key,$name) = @_;
	if ($key  eq "") {return ""}
	if ($name eq "") {return ""}
	return &data_get("sys_config",$key,$name);
}
sub system_config_set(){
	local($key,$name,$value) = @_;
	if ($key  eq "") {return ""}
	if ($name eq "") {return ""}
	return &data_set("sys_config",$key,$name,$value);
}
sub system_encode_user_password(){
	local($password,$extra_salt) = @_;
	return md5_hex($password."pbx".$extra_salt);
}
#------------------------
#
#
#
#------------------------
# generic perl library
#------------------------
sub get_today(){
	local($my_time)=@_;
	local (%out,@mes_extenso,$sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
	@mes_extenso = qw (ERROR Janeiro Fevereiro Março Abril Maio Junho Julho Agosto Setembro Outubro Novembro Dezembro);
	if ($my_time eq "") {
		($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =	localtime(time);
	} else {
		($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =	localtime($my_time);
	}
	if ($year < 1000) {$year+=1900}
	$mon++;
	$out{DAY}		= $mday;
	$out{MONTH}		= $mon;
	$out{YEAR}		= $year;
	$out{HOUR}		= $hour;
	$out{MINUTE}	= $min;
	$out{SECOND}	= $sec;
	$out{DATE_ID}	= substr("0000".$year,-4,4) . substr("00".$mon,-2,2) . substr("00".$mday,-2,2);
	$out{TIME_ID}	= substr("00".$hour,-2,2) . substr("00".$min,-2,2) . substr("00".$sec,-2,2);
	$out{DATE_TO_PRINT} = &format_date($out{DATE_ID});
	$out{TIME_TO_PRINT} = substr("00".$hour,-2,2) . ":" . substr("00".$min,-2,2);
	return %out;
}
sub format_date(){
	local($in)=@_;
	local($out,$tmp1,$tmp2,@mes_extenso);
	@mes_extenso = qw (ERROR Janeiro Fevereiro Março Abril Maio Junho Julho Agosto Setembro Outubro Novembro Dezembro);
	@mes_extenso = qw (ERROR Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	if (length($in) eq 8) {
		$tmp1=substr($in,4,2);
		$tmp2=substr($in,6,2);
		$tmp1++;$tmp1--;
		$tmp2++;$tmp2--;
		$out = (@mes_extenso)[$tmp1] . " $tmp2, " . substr($in,0,4);
	} elsif (length($in) eq 14) {
		$tmp1=substr($in,4,2);
		$tmp2=substr($in,6,2);
		$tmp1++;$tmp1--;
		$tmp2++;$tmp2--;
		$out = (@mes_extenso)[$tmp1] . " $tmp2, " . substr($in,0,4)  ." at ".substr($in,8,2).":".substr($in,10,2) ;
	} else {
		$tmp1=substr($in,4,2);
		$tmp1++;$tmp1--;
		$out = (@mes_extenso)[$tmp1] . ", " .substr($in,0,4);
	}
	return $out;
}

sub time2str() {
	local ($time) = @_;
	%out = &get_today($time);
	
	return "$out{DATE_TO_PRINT}  $out{TIME_TO_PRINT}"; 
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
sub clean_int() {
  #limpa tudo que nao for letras e numeros
  local ($old)=@_;
  local ($new,$pre,$i);
  $pre="";
  $old=$old."";
  if (substr($old,0,1) eq "+") {$pre="+";$old=substr($old,1,1000);}
  if (substr($old,0,1) eq "-") {$pre="-";$old=substr($old,1,1000);}
  $new="";
  $caracterok="1234567890";
  for ($i=0;$i<length($old);$i++) {if (index($caracterok,substr($old,$i,1))>-1) {$new=$new.substr($old,$i,1);} }
  return $pre.$new;
}
sub clean_float() {
	local ($old)=@_;
	local ($new,$n1,$n2);
	if (index($old,".") ne -1) {
		($n1,$n2) = split(/\./,$old);
		$new = &clean_int($n1).".".&clean_int($n2);
	} else {
		$new = &clean_int($old);
	}
	return $new;
}
sub clean_html {
  local($trab)=@_;
  local($id,@okeys);
  @okeys=qw(b i h1 h2 h3 h4 h5 ol ul li br p B I H1 H2 H3 H4 H5 OL UL LI BR P);
  foreach(@okeys) {
    $id=$_;
    $trab=~ s/<$id>/[$id]/g;
    $trab=~ s/<\/$id>/[\/$id]/g;
  }
  $trab=~ s/</ /g;
  $trab=~ s/>/ /g;
  foreach(@okeys) {
    $id=$_;
    $trab=~ s/\[$id\]/<$id>/g;
    $trab=~ s/\[\/$id\]/<\/$id>/g;
  }
  return $trab;
}
sub is_numeric() {
	local($num) = @_;
	$num = trim($num);
	$p1 = "";
	$p1 = (substr($num,0,1) eq "-") ? "-" : $p1;
	$p1 = (substr($num,0,1) eq "+") ? "+" : $p1;
	$p0 = ($p1 eq "") ? $num : substr($num,1,1000);
	$p5="";
	if (index($p0,".")>-1) {
		($p2,$p3,$p4) = split(/\./,$p0);
		$p2 =~ s/[^0-9]/$p5/eg;
		$p3 =~ s/[^0-9]/$p5/eg;
		if ( ("$p1$p2.$p3" eq $num) && ($p4 eq "") ){return 1} else {return 0}
	} else {
		$p0 =~ s/[^0-9]/$p5/eg;
		if ("$p1$p0" eq $num) {return 1} else {return 0}
	}
}
sub trim {
     my @out = @_;
     for (@out) {
         s/^\s+//;
         s/\s+$//;
     }
     return wantarray ? @out : $out[0];
}
sub format_number {
	local $_  = shift;
	local $dec = shift;
	#
	# decimal 2 its a magic number.. 2 decimals but more decimals for small numbers
	if (!$dec) {
		$dec="%.0f";
	} elsif ($dec eq 2) {
		$dec="%.2f";
		if($_<0.05) 		{$dec="%.3f"}
		if($_<0.005) 		{$dec="%.4f"}
		if($_<0.0005) 		{$dec="%.5f"}
		if($_<0.00005) 		{$dec="%.7f"}
		if($_<0.000005) 	{$dec="%.8f"}
		if($_<0.0000005) 	{$dec="%.9f"}
		if($_<0.00000005) 	{$dec="%g"}
	} else {
		$dec="%.".$dec."f";
	}
	$_=sprintf($dec,$_);
	1 while s/^(-?\d+)(\d{3})/$1,$2/;
	return $_;
}
sub format_time {
        local ($sec) = @_;
        local ($out,$min,$hour,$tmp);
        $sec = int($sec);
        if ($sec < 60) {
                $out = substr("00$sec",-2,2)."s";
                $out = $sec."s";
        } elsif ($sec < (60*60) ) {
                $min = int($sec/60);
                $sec = $sec - ($min*60);
                $out = substr("00$min",-2,2)."m ".substr("00$sec",-2,2)."s";
                $out = $min."m ".$sec."s";
        } else {
                $hour = int($sec/(60*60));
                $sec = $sec - ($hour*(60*60));
                $min = int($sec/60);
                $sec = $sec - ($min*60);
                $out = $hour."h ".substr("00$min",-2,2)."m ".substr("00$sec",-2,2)."s";
                $out = $hour."h ".$min."m ".$sec."s";
        }
        return $out;
}
sub format_time_gap {
        local ($time) = @_;
        local ($out,$gap,%d,$min,$hour,$days,%tmpd);
        %d = &get_today($time);
        $sec = int(time-$time);
        if ($sec < 60) {
            $out = "$sec seconds ago";
        } elsif ($sec < (60*60) ) {
            $min = int($sec/60);
            $sec = $sec - ($min*60);
            $out = "$min minutes ago";
        } elsif ($sec < (60*60*6))  {
            $hour = int($sec/(60*60));
            $sec = $sec - ($hour*(60*60));
            $min = int($sec/60);
            $sec = $sec - ($min*60);
            $out = "$hour hours ago";
        } elsif ($sec < (60*60*24*60))  {
	    	%tmpd = &get_today($time);
            $out = "$tmpd{MONTH}/$tmpd{DAY} $tmpd{HOUR}:".substr("00".$tmpd{MINUTE},-2,2);
        } else {
	    	%tmpd = &get_today($time);
            $out = "$tmpd{MONTH}/$tmpd{DAY}/".substr($tmpd{YEAR},-2,2)." $tmpd{HOUR}:".substr("00".$tmpd{MINUTE},-2,2);
        }
        return $out ;
}
sub format_time_time {
        local ($time) = @_;
        local ($out,$gap,%d,$min,$hour,$days);
        %d = &get_today($time);
        return "$d{DATE_TO_PRINT} $d{TIME_TO_PRINT}" ;
}
sub check_email() {
  local ($old_email)=@_;
  local ($tmp1,$tmp2,$tmp2,$email,$ok);
  ($tmp1,$tmp2,$tmp3)=split(/\@/,$old_email);
  $tmp1 = &clean_str($tmp1,"._-","MINIMAL");
  $tmp2 = &clean_str($tmp2,"._-","MINIMAL");
  $email = "$tmp1\@$tmp2";
  $ok = 1;
  if (index($email,"@") eq -1) 	{$ok=0;}
  if (index($email,".") eq -1) 	{$ok=0;}
  if ($tmp3 ne "") 				{$ok=0;}
  if ($email ne $old_email) 	{$ok=0;}
  return $ok
}
sub format_dial_number() {
	my($in) = @_;
	my($out,$length);
	$in=&clean_int(substr($in,0,100));
	$out=$in;
	$length=length($in);
	if ($length eq 5) {
		$out = substr($in,0,2)."-".substr($in,2,3);
	} elsif ($length eq 6) {
		$out = substr($in,0,3)."-".substr($in,3,3);
	} elsif ($length eq 7) {
		$out = substr($in,0,3)."-".substr($in,3,4);
	} elsif ($length eq 8) {
		$out = substr($in,0,4)."-".substr($in,4,4);
	} elsif ($length eq 9) {
		$out = "(".substr($in,0,2).") ".substr($in,2,3)."-".substr($in,5,3);
	} elsif ($length eq 10) {
		$out = "(".substr($in,0,3).") ".substr($in,3,3)."-".substr($in,6,4);
	} elsif ($length eq 11) {
		$out = substr($in,0,1)." (".substr($in,1,3).") ".substr($in,4,3)."-".substr($in,7,4);
	} elsif ($length eq 12) {
		$out = substr($in,0,2)." (".substr($in,2,3).") ".substr($in,5,3)."-".substr($in,8,4);
	}
	return($out)
}
sub format_E164_number() {
	my($in,$format_type) = @_;
	my($out,%hash,$contry,$tmp);
	#
	#
	if ($in eq "") {return ""}
	#
	# get country list
	if ($app{country_buffer} eq "") {
	    %hash = &database_select_as_hash("select code,name from country ");
	    $app{country_buffer} = "|";
		$app{country_max_length} = 0;
	    foreach (keys %hash) {
			$app{country_buffer} .= "$_|";
			$app{country_max_length} = (length($_)>$app{country_max_length}) ? length($_) : $app{country_max_length};
		}
	}
	$country = "";
	foreach $tmp (1..$app{country_max_length}) {
		$tmp1 = substr($in,0,$tmp);
		if (index($app{country_buffer},"|$tmp1|") ne -1) {$country = $tmp1;}
	}
	$out = $in;
	if ($format_type eq "E164") {
		if ($country eq "") {
			$out = "+$in";
		} elsif ($country eq "1") {
			$out = "+1 (".substr($in,1,3).") ".substr($in,4,3)."-".substr($in,7,4);
		} elsif ($country eq "55") {
			$out = "+55 (".substr($in,2,2).") ".substr($in,4,4)."-".substr($in,8,4);
		} else {
			$tmp = length($country);
			$out = "+$country (".substr($in,$tmp,3).") ".substr($in,$tmp+3,3)."-".substr($in,$tmp+6,1000);
		}
	} elsif ($format_type eq "USA") {
		if ($country eq "") {
			$out = "+$in";
		} elsif  ( ($country eq "1") && (length($in) eq 11)) {
			$out = "(".substr($in,1,3).") ".substr($in,4,3)."-".substr($in,7,4);
		} elsif ($country eq "55") {
			$out = "011 55 (".substr($in,2,2).") ".substr($in,4,4)."-".substr($in,8,4);
		} else {
			$tmp = length($country);
			$out = "011 $country (".substr($in,$tmp,3).") ".substr($in,$tmp+3,3)."-".substr($in,$tmp+6,1000);
		}
	} else {
	}
	return $out;
}

sub _() {
	local ($msg) = @_;
	return $msg;
}

sub pbx_debug() {
	local $hash = shift;
	use Data::Dumper;
	warn Dumper($hash);
}

sub check_domain_change() {
	local ($uuid) = @_;
	
	$current_domain_uuid = '';
	$id = $app{websession_id};
	local $mem_id = "currentdomain_$id";
    
    $cached_interval      = 10;
    $raw = $memcache->get($mem_id);
	
    if (defined($raw)){
        $current_domain_uuid = $ref;
		return if $uuid eq $current_domain_uuid;
    }
        
    $memcache->set($mem_id, $uuid, $cached_interval*60);
	
	return 1;    
}
#------------------------

