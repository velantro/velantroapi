#!/usr/bin/perl
################################################################################
#
# global libs for AGI, perl scripts and CGI
# extra libs for multilevel services  
# developed for years to zenofon
#
################################################################################
$|=1;$!=1; # disable buffer 
use File::Copy;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use DBI;
use LWP 5.69;
use Data::Dumper;
use Carp; $SIG{ __DIE__ } = sub { Carp::confess( @_ ) };
$app_root							= "/usr/local/owsline/";
$host_name							= "neyfrota-dev";
%template_buffer					= ();
$database 							= null;
$conection 							= null;
$database_connected					= 0;
$database_last_error				= "";
# in future, move database settings to externalfile. 
# Use hardcode make life complex to manage production and multiple development base
# all other data need leave in database


#
# in future, make this thing permanent in modperl.
# TODO: do we really need that? are we using that?
%global_cache	= (); 
%cache_request	= ();
%cache_session	= ();
%cache_user		= ();
%cache_global	= ();
#
# hard code hosts
$hardcoded_call_server_ip 	= "127.0.0.1";
$hardcoded_stream_server_ip = "127.0.0.1";
#$hardcoded_stream_server_ip = "10.0.1.9";
$hardcoded_call_server 		= "local";
$hardcoded_stream_server 	= "local";
$hardcoded_webservice_host	= "www.uslove.com";
%app						= ();

use JSON; # to install, # sudo cpan JSON
$json_engine	= JSON->new->allow_nonref;

&default_include_init();
return 1;
#=======================================================



sub default_include_init(){
	open(IN,"/etc/pbx-v2.conf"); while (<IN>) { chomp($_); ($tmp1,$tmp2) = split(/\=/,$_,2); $app{&trim("\L$tmp1")}=$tmp2; } close(IN);
	$app{app_root}			= $app{app_root} || "/etc/";
	##$app{host_name}			= $app{host_name} || "dev-desktop";# we need remove all calls to this variable. we need use server_id instead
	$app{server_id}			= $app{server_id} || "1";
	$app{database_dsn}		= $app{database_dsn} || "DBI:Pg:database=fusionpbx;host=127.0.0.1";
	$app{database_user}		= $app{database_user} || "fusionpbx";
	$app{database_password}	= $app{database_password} || "fusionpbx";
	
	$app{log_file}		= '/tmp/pbx.log';
	open LOG, ">> $app{log_file}";

}


#------------------------
#
#
#------------------------
# some lost things 
#------------------------
sub sql_to_hash_by_page(){
	#
	# basic, query sql database by page and put in hash
	# $data{DATA} is the same format as template loops. just drop DATA in the loop you want
	# remeber you NEED add " LIMIT #LIMIT1 , #LIMIT2" in your DATA query in order to limit page itens. 
	# 
	# her is a example how to query and add on template hash.
	# 
	#	==== CGI START ====
	#   %template_data = ();
	#	%users_list = &sql_to_hash_by_page((
	#		'sql_total'=>"SELECT count(*) FROM users ", 
	#		'sql_data'=>"SELECT id,name,phone FROM users ORDER BY date desc LIMIT #LIMIT1 , #LIMIT2 ",
	#		'sql_data_names'=>"user_id,user_name,user_phone",
	#		'page_now'=>$form{page_number},
	#		'page_size'=>5
	#	));
	#	if ($users_list{OK} eq 1){
	#		#
	#		# put DATA into users_list loop
	#	    $template_data{users_list_found}= 1;
	#		%{$template_data{users_list}}	= %{$users_list{DATA}};
	#		#
	#		# create loop with page info
	#		$template_data{users_list_page_min} = $users_list{page_min};
	#		$template_data{users_list_page_max} = $users_list{page_max};
	#		$template_data{users_list_page_now} = $users_list{page_now};
	#		$template_data{users_list_page_previous} = ($template_data{page_now} > $template_data{page_min}) ? $template_data{page_now}-1 : "";
	#		$template_data{users_list_page_next} = ($template_data{page_now} < $template_data{page_max}) ? $template_data{page_now}+1 : "";
	#		foreach $p ($users_list{page_min}..$users_list{page_max}) {
	#			$template_data{users_list_pages}{$p}{page} = $p;
	#			$template_data{users_list_pages}{$p}{selected} = ($p eq $t{thread_page}) ? 1 : 0;
	#		}
	#	}
	#    &template_print("template.html",%template_data);
	#	==== CGI STOP ====
	#
	#	==== TEMPLATE.HTML START ====
	#	<table>
	#	<TMPL_LOOP NAME="users_list">
	#		<tr>
	#		<td>%user_id%</td>
	#		<td>%user_name%</td>
	#		<td>%user_phone%</td>
	#		</tr>
	#	</TMPL_LOOP>
	#	</table>
	#	<br>
	#	Page %users_list_page_now% of %users_list_page_max%<br>
	#	Select page: 
	#	<TMPL_LOOP NAME="users_list_pages"><a href=?page_number=%page%>%page%</a>,</TMPL_LOOP>
	#	==== TEMPLATE.HTML STOP ====
	#
	local(%data) = @_;
	local(%hash,%hash1,$hash2,$tmp,$tmp1,$tmp2,@array,@array1,@array2);
	#
	# pega page limits
	%hash = &database_select($data{sql_total});
	$data{count} 		= ($hash{OK} eq 1) ? &clean_int($hash{DATA}{0}{0}) : 0;
	$data{count}		= ($data{count} eq "") ? 0 : $data{count};
	$data{page_size}	= &clean_int($data{page_size});
	$data{page_size}	= ($data{page_size} eq "") ? $workgroup_config{page_size} : $data{page_size};
	$data{page_size}	= ($data{page_size} > 1024) ? 1024 : $data{page_size};
	$data{page_size}	= ($data{page_size} < 1 ) ? 1 : $data{page_size};
	$data{page_min}		= 1;
	$data{page_max}		= int(($data{count}-1)/$data{page_size})+1;
	$data{page_max}		= ($data{page_max}<$data{page_min}) ? $data{page_min} : $data{page_max};
	$data{page_now} 	= &clean_int($data{page_now});
	$data{page_now} 	= ($data{page_now}<$data{page_min}) ? $data{page_min} : $data{page_now};
	$data{page_now} 	= ($data{page_now}>$data{page_max}) ? $data{page_max} : $data{page_now};
	$data{sql_limit_1}	= ($data{page_now}-1)*$data{page_size};
	$data{sql_limit_2}	= $data{page_size};
	#
	# pega ids
	if ($data{count} > 0){
		$data{sql_data_run} = $data{sql_data};
		$tmp2=$data{sql_limit_1}; $tmp1="#LIMIT1"; $data{sql_data_run} =~ s/$tmp1/$tmp2/eg;
		$tmp2=$data{sql_limit_2}; $tmp1="#LIMIT2"; $data{sql_data_run} =~ s/$tmp1/$tmp2/eg;
		%hash = &database_select($data{sql_data_run},$data{sql_data_names});
		if ($hash{OK} eq 1) {
			%{$data{DATA}} = %{$hash{DATA}};
			$data{ROWS}	= $hash{ROWS};
			$data{COLS}	= $hash{COLS};
			$data{OK}	= 1;
		}
	}
	#
	# return
	return %data;
}
sub send_email(){
	local ($from,$to,$subject,$message,$has_head) = @_;
	local ($email_raw);
	$email_raw = "";
	$email_raw .= "from:$from\n";
	##$email_raw .= "To: $to\n";
	if (index("\U$message","SUBJECT:") eq -1) {$email_raw .= "Subject: $subject\n";}
	$email_raw .= "MIME-Version: 1.0\n";
	##$email_raw .= "Delivered-To: $to\n";
	if ($has_head ne 1) {$email_raw .= "\n";}
	$email_raw .= "$message\n";
	open(SENDMAIL,">>$app_root/website/log/send_email.log");
	print SENDMAIL  "\n";
	print SENDMAIL  "\n";
	print SENDMAIL  "#########################################################\n";
	print SENDMAIL  "## \n";
	print SENDMAIL  "## NEW EMAIL TIME=(".time.") to=($to)\n";
	print SENDMAIL  "## \n";
	print SENDMAIL  "#########################################################\n";
	print SENDMAIL $email_raw;
	close(SENDMAIL);
	open(SENDMAIL, "|/usr/sbin/sendmail.postfix $to");
	print SENDMAIL $email_raw;
	close(SENDMAIL);
}
#------------------------
#
#------------------------

#------------------------
# clickchain (protect from url forge)

# CSV tools
#------------------------
sub csvtools_line_split_values(){
	local($line_raw) = @_; 
	local(@array,%hash,$tmp,,$tmp1,$tmp2,@1,@a2);
	local(@values);
    chomp($line_raw);
    chomp($line_raw);
    if (index($line_raw,",") eq -1) {$tmp1 = "\t"; $tmp2=","; $line_raw =~ s/$tmp1/$tmp2/eg;}
	@data = ();
	foreach $tmp (split(/\,/,$line_raw)) {
		$tmp1="\""; $tmp2=" "; $tmp =~ s/$tmp1/$tmp2/eg; 
		$tmp1="\'"; $tmp2=" "; $tmp =~ s/$tmp1/$tmp2/eg; 
		$tmp = trim($tmp);
		@data = (@data,$tmp);
	}
	return (@data);
}
sub csvtools_line_join_values(){
	local(@d) = @_;
	return join(",",@d);
}
#

# i just prototype this things..
# not working as the way i want
# later need comeback and fix the magic
#------------------------
sub form_check_float(){
	my ($v,$f) = @_;
	$v=trim($v);
	if ($v eq "") {return 0}
	$v++;
	$v--;
	if ($v eq "0") {return 1}
	if ($v>0) {return 1}
	if ($v<0) {return 1}
	return 0;
}
sub form_check_integer(){
	my ($v,$f) = @_;
	$v=trim($v);
	if (index("\L$f","allow_blank") eq -1){
		if ($v eq "") {return 0}
	}
	if ($v ne &clean_int($v)) {return 0}
	return 1;
}
sub form_check_number(){
	my ($v,$f) = @_;
	$v=trim($v);
	if (index("\L$f","allow_blank") eq -1){
		if ($v eq "") {return 0}
	}
	if ($v ne &clean_int($v)) {return 0}
	return 1;
}
sub form_check_string(){
	my ($v,$f) = @_;
	$v=trim($v);
	if (index("\L$f","allow_blank") eq -1){
		if ($v eq "") {return 0}
	}
	if ($v ne &clean_str($v," /-_–(\@)-,=+;.<>[]:?<>","MINIMAL")) {return 0}
	return 1;
}
sub form_check_url(){
	my ($v,$f) = @_;
	$v=trim($v);
	if (index("\L$f","allow_blank") eq -1){
		if ($v eq "") {return 0}
	}
	if ($v ne &clean_str($v," /&?-_–(\@)-,=+;.<>[]:?<>","MINIMAL")) {return 0}
	return 1;
}
sub form_check_textarea(){
	my ($v,$f) = @_;
	$v=trim($v);
	if (index("\L$f","allow_blank") eq -1){
		if ($v eq "") {return 0}
	}
	if ($v ne &clean_str($v," -_–(\@)-,=+;.[]:?","MINIMAL")) {return 0}
	return 1;
}
sub form_check_sql(){
	my ($v,$f) = @_;
	$v=trim($v);
	if (index("\L$f","allow_blank") eq -1){
		if ($v eq "") {return 0}
	}
	if ($v ne &clean_str($v," *-_–(\@)-,<>=+;.[]:?","MINIMAL")) {return 0}
	return 1;
}
sub form_check_email(){
	my ($v) = @_;
	$v=trim($v);
	if ($v eq "") {return 0}
	if ($v ne &clean_str($v,"–()_-=+;.?<>@","MINIMAL")) {return 0}
	if (index($v,"@") eq -1) {return 0}
	return 1;
}
#------------------------
#
#------------------------


#------------------------
# database abstraction
#------------------------
sub database_connect(){
	if ($database_connected eq 0) {
		$database = DBI->connect($app{database_dsn}, $app{database_user}, $app{database_password});
		$database->{mysql_auto_reconnect} = 1;
		$database_connected = 1;
	}
}
sub database_select(){
	if ($database_connected ne 1) {database_connect()}
	local ($sql,$cols_string)=@_;
	local (@rows,@cols_name,$connection,%output,$row,$col,$col_name);
	@cols_name = split(/\,/,$cols_string);
	if ($database_connected eq 1) {
		$connection = $database->prepare($sql);
		$connection->execute;
		$row=0;
		while ( @rows = $connection->fetchrow_array(  ) ) {
			$col=0;
			foreach (@rows){
				$col_name =  ((@cols_name)[$col] eq "")  ? $col : (@cols_name)[$col] ; 
				$output{DATA}{$row}{$col_name}= $_;
				#$output{DATA}{$row}{$col}= &database_scientific_to_decimal($_);
				$col++;
			}
			$row++;
		}
		$output{ROWS}=$row;
		$output{COLS}=$col;
		$output{OK}=1;
	} else {
		$output{ROWS}=0;
		$output{COLS}=0;
		$output{OK}=0;
	}
	return %output;
}
sub database_select_as_hash(){
	if ($database_connected ne 1) {database_connect()}
	local ($sql,$rows_string)=@_;
	local (@rows,@rows_name,$i,%output);
	@rows_name = split(/\,/,$rows_string);
	if ($database_connected eq 1) {
		$connection = $database->prepare($sql);
		$connection->execute;
		while ( @rows = $connection->fetchrow_array(  ) ) {
			if ($rows_string eq "") {
				$output{(@rows)[0]}=(@rows)[1];
			} else {
				$i=0;
				foreach (@rows_name) {
					##$output{(@rows)[0]}{$_} = &database_scientific_to_decimal((@rows)[$i+1]);
					$output{(@rows)[0]}{$_} = (@rows)[$i+1];
					$i++;
				}
			}
		}
	}
	return %output;
}
sub database_select_as_hash_with_auto_key(){
	if ($database_connected ne 1) {database_connect()}
	local ($sql,$rows_string)=@_;
	local (@rows,@rows_name,$i,%output,$line_id);
	@rows_name = split(/\,/,$rows_string);
	if ($database_connected eq 1) {
		$connection = $database->prepare($sql);
		$connection->execute;
		$line_id = 0;
		while ( @rows = $connection->fetchrow_array(  ) ) {
			$i=0;
			foreach (@rows_name) {
				$output{$line_id}{$_} = &database_scientific_to_decimal((@rows)[$i]);
				$i++;
			}
			$line_id++;
		}
	}
	return %output;
}
sub database_select_as_array(){
	if ($database_connected ne 1) {database_connect()}
	local ($sql,$rows_string)=@_;
	local (@rows,@rows_name,$i,@output);
	@rows_name = split(/\,/,$rows_string);
	if ($database_connected eq 1) {
		$connection = $database->prepare($sql);
		$connection->execute;
		while ( @rows = $connection->fetchrow_array(  ) ) {
			@output = ( @output , &database_scientific_to_decimal((@rows)[0]) );
		}
	}
	return @output;
}
sub database_do(){
	if ($database_connected ne 1) {database_connect()}
	local ($sql)=@_;
	local ($output);
	$output = "";
	if ($database_connected eq 1) {	$output = $database->do($sql) }
	if ($output eq "") {$output =-1;}
	return $output;
}
sub database_scientific_to_decimal(){
	local($out)=@_;
	local($tmp1,$tmp2);
	if ( index("\U$out","E-") ne -1) {
		($tmp1,$tmp2) = split("E-","\U$out");
 		$tmp1++;
		$tmp2++;
		$tmp1--;
		$tmp2--;
		if (  (&is_numeric($tmp1) eq 1) && (&is_numeric($tmp2) eq 1)  )  {
			$out=sprintf("%f",$out);
		}
	}
	if ( index("\U$out","E+") ne -1) {
		($tmp1,$tmp2) = split("E","\U$out");
		$tmp2 = substr($tmp2,1,10);
		$tmp1++;
		$tmp2++;
		$tmp1--;
		$tmp2--;
		if (  (&is_numeric($tmp1) eq 1) && (&is_numeric($tmp2) eq 1)  )  {
			$out=int(sprintf("%f",$out));
		}
	}
	return $out;
}
sub database_clean_string(){
	my $string = @_[0];
	return &database_escape($string);
}
sub database_clean_number(){
	my $string = @_[0];
	return &database_escape($string);
}
sub database_escape {
	my $string = @_[0];
	$string =~ s/\\/\\\\/g ; # first escape all backslashes or they disappear
	$string =~ s/\n/\\n/g ; # escape new line chars
	$string =~ s/\r//g ; # escape carriage returns
	$string =~ s/\'/\\\'/g; # escape single quotes
	$string =~ s/\"/\\\"/g; # escape double quotes
	return $string ;
}
sub database_do_insert(){
	if ($database_connected ne 1) {database_connect()}
	local ($sql)=@_;
	local ($output,%hash,$tmp);
	$output = "";
	#
	# new code (return last insert_id)
	if ($database_connected eq 1) {
		if ($database->do($sql)) {
			%hash = &database_select_as_hash("SELECT 1,LAST_INSERT_ID();");
			return $hash{1};
		} else {
			return "";
		}
	} else {
		return "";
	}
}
sub database_escape_sql(){
	local($sql,@values) = @_;
	retutn &database_scape_sql($sql,@values);
}
sub database_scape_sql(){
	local($sql,@values) = @_;
	local($tmp,$tmp1,$tmp2);
	$tmp1="\t"; $tmp2=" "; $sql =~ s/$tmp1/$tmp2/eg;
	$tmp1="\n"; $tmp2=" "; $sql =~ s/$tmp1/$tmp2/eg;
	$tmp1="\r"; $tmp2=" "; $sql =~ s/$tmp1/$tmp2/eg;
	$tmp = @values;
	$tmp--;
	if ($tmp>0) {
		foreach (0..$tmp) {
			$values[$_] = &database_escape($values[$_]);
		}
	}
	return  sprintf($sql,@values);
}
#------------------------
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
  for ($i=0;$i<length($old);$i++) {if (index($caracterok,substr($old,$i,1))>-1) {$new=$new.substr($old,$i,1);} }
  return $new;
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
sub multiformat_phone_number_check_user_input(){
	my($in) = @_;
	my($out,%hash,$tmp1,$tmp2,$contry,$tmp);
	my($flag,$number_e164,$country);
	if (trim($in) eq "") {return ("EMPTY","UNKNOWN",$in);}

	$tmp = "\U$in";
	unless($tmp =~ m/[A-Z]/) {

		#
		# numeric.. lets check e164
		($flag,$number_e164,$country) = &multilevel_check_E164_number(&clean_int($in));
		if ($flag eq "USANOAREACODE") {
			return ("OK","E164","1$number_e164");
		} elsif ($flag eq "UNKNOWNCOUNTRY") {
			return ("UNKNOWNCOUNTRY","E164",$in);
		} elsif ($flag eq "OK") {
			return ("OK","E164",$number_e164);
		} else {
			return ("ERROR","E164",$in);
		}
	} else {
		# 
		# alpha, lets clean skype
		if (index($in,":") ne -1){	
			($tmp1,$tmp2) = split(/\:/,$in);$in = $tmp2; 
		}
		$tmp = &trim($in);
		$tmp1 = &clean_str($tmp,"-_.","MINIMAL");
		if ( ($tmp1 eq $tmp) && (length($tmp1)>=6) && (length($tmp1)<=32) ) {
			return ("OK","SKYPE",$tmp);
		} else {
			return ("ERROR ($in) ($tmp) ($tmp1) (".length($tmp1).") ","SKYPE",$in);
		}
	}
}
sub multiformat_phone_number_format_for_user(){
	my($in,$format_type) = @_;
	my($out,%hash,$tmp1,$tmp2,$contry,$tmp);
	if ($in eq "") {return "";}
	if (&clean_int($in) eq $in){
		return &format_E164_number($in,$format_type);
	} else {
		return "Skype: $in";
	}
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
sub format_key_code(){
	local($in)=@_;
	local($t,$t1,$t2,$o,$c,$l,@a);
	$c = 0;
	$l = 1;
	$o = "";
	@a = ();
	while($l eq 1) {
		$t1 = trim(substr($in,-3,3));
		$t2 = trim(substr($in,0,-3));
		@a = (substr("0000$t1",-3,3),@a);
		if ($t2 eq "") {$l=0}
		$c++; if ($c>20){last}
		$in = $t2;
	}
	$o = join("-",@a);
	return $o;
}
sub format_pin(){
	local($in)=@_;
	local($t,$t1,$t2,$out,$c,$l,@a);
	$out=$in;
	if (length($in) eq 8){
		#$out = substr($in,0,3)."-".substr($in,3,2)."-".substr($in,5,3);
		$out = substr($in,0,2)."-".substr($in,2,2)."-".substr($in,4,4);
	}
	return $out;
}
sub format_trim_name(){
	local($in,$flag) = @_;
	local($out,$w);
	$out=$in;
	#
	# hack: show all names with no obfuscate
	$flag = 0;
	#
	if ($flag eq 1) {
	    $out = "";
	    foreach $w (split (/ +/,$in)){
		if ($w eq "") {next}
		$out .= (length($w)>2) ? substr("\U$w",0,1)."**** " : "$w ";
	    }
	}
	return $out;
}
#------------------------
sub genuuid () {
  @char = (0..9,'a'..'f');
  $size = int @char;
  local $uuid = '';
  for (1..8) {
      $s = int rand $size;
      $uuid .= $char[$s];
  }
  $uuid .= '-';
  for (1..4) {
      $s = int rand $size;
      $uuid .= $char[$s];
  }
  $uuid .= '-4';

  for (1..3) {
      $s = int rand $size;
      $uuid .= $char[$s];
  }
  $uuid .= '-8';
  for (1..3) {
      $s = int rand $size;
      $uuid .= $char[$s];
  }
  $uuid .= '-';

  for (1..12) {
      $s = int rand $size;
      $uuid .= $char[$s];
  }

  return $uuid;
}
  
sub Json2Hash(){
	local($json_plain) = @_;
	local(%json_data);
	my %json_data = ();
	if ($json_plain ne "") {
		local $@;
		eval {
			$json_data_reference	= $json_engine->decode($json_plain);
		};
		
		if ($@) {warn $@}
		%json_data			= %{$json_data_reference};
	}
	return %json_data;
}
sub Hash2Json(){
	local(%jason_data) = @_;
	# hack: error.code need be a numeric if value is 0
	#if ( exists($jason_data{error}) ){
	#	if ($jason_data{error}{code} == "0"){
	#		$jason_data{error}{code} = 0;
	#	}
	#}
	my $json_data_reference = \%jason_data;
	my $json_data_text		= $json_engine->encode($json_data_reference);
	return $json_data_text;
}
