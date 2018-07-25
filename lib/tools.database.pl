#!/usr/bin/perl
=pod
	Version 1.0
	Developed by Velantro inc
	Contributor(s):
	George Gabrielyan <george@velantro.com>
=cut


################################################################################
#
# database we need for pbx
#
################################################################################
use DBI;
$database_connection 	= null;
$database_session 		= null;
$database_connected		= 0;
$database_last_error	= "";
return 1;
sub tools_database_init(){
}
################################################################################



################################################################################
sub database_check_connection(){
	if ($database_connected ne 1) {database_connect()}
	if ($database_connected eq 1) {
		if ($database_connection->ping) {
			return 1;
		} else {
			if (exists &pbx_log_debug_no_flood) { &pbx_log_debug_no_flood("DB_DISCONNECT_WARNING|".DBI->err."|".DBI->errstr) }
			&database_disconnect();
			&database_connect();
			if ($database_connected eq 1) {return 1}
			return 0;
		}
	} else {
		return 0;
	}
}
sub database_connect(){
	if ($database_connected eq 0) {
		$database_connection = DBI->connect($app{database_dsn}, $app{database_user}, $app{database_password});
		if ( DBI->err ){
			if (exists &pbx_log_debug_no_flood) { &pbx_log_debug_no_flood("DB_CONNECT_WARNING|".DBI->err."|".DBI->errstr) }
			$database_connection = DBI->connect($app{database_dsn}, $app{database_user}, $app{database_password});
			if ( DBI->err ){
				if (exists &pbx_log_error_no_flood) { &pbx_log_error_no_flood("error_code=DB_CONNECT_FAIL|".DBI->err."|".DBI->errstr) }
			} else {
				$database_connected = 1;
			}
		} else {
			$database_connected = 1;
		}
	}
}
sub database_desconnect(){ # dEsconnect??? what a dub error :( we need check all code and fix all references to this : ( 
	&database_disconnect();
}
sub database_disconnect(){
	if ($database_connected eq 1) {
		$database_connection->disconnect();
		$database_connection 	= null;
		$database_session 		= null;
		$database_connected		= 0;
		$database_last_error	= "";
	}
}
sub database_select(){
	local ($sql,$cols_string)=@_;
	local (@rows,@cols_name,%output,$row,$col,$col_name);
	@cols_name = split(/\,/,$cols_string);
	%output = ();
	$output{ROWS}=0;
	$output{COLS}=0;
	$output{OK}=0;
	#
	unless (&database_check_connection()) {return %output}
	#
	$database_session = $database_connection->prepare($sql);
	$database_session->execute;
	if ( $database_session->err ){
		if (exists &pbx_log_debug_no_flood) { &pbx_log_debug_no_flood("DB_WARNING|".$database_session->err."|".$database_session->errstr."|".&database_clean_sql($sql)) }
		$database_session = $database_connection->prepare($sql);
		$database_session->execute;
		if ( $database_session->err ){
			if (exists &pbx_log_error_no_flood) { &pbx_log_error_no_flood("error_code=DB_FAIL|".$database_session->err."|".$database_session->errstr."|".&database_clean_sql($sql)) }
			return %output;
		}
	}
	#
	$row=0;
	while ( @rows = $database_session->fetchrow_array(  ) ) {
		$col=0;
		foreach (@rows){
			$col_name =  ((@cols_name)[$col] eq "")  ? $col : (@cols_name)[$col] ; 
			$output{DATA}{$row}{$col_name}= $_;
			$col++;
		}
		$row++;
	}
	$output{ROWS}=$row;
	$output{COLS}=$col;
	$output{OK}=1;
	return %output;
}
sub database_select_as_hash_with_key(){
	#
	local ($sql, $key, $rows_string)=@_;
	local (@rows,@rows_name,$i,%output);
	%output = ();
	@rows_name = split(/\,/,$rows_string);
	#
	unless (&database_check_connection()) {return %output}
	#
	$database_session = $database_connection->prepare($sql);
	$database_session->execute;
	if ( $database_session->err ){
		if (exists &pbx_log_debug_no_flood) { &pbx_log_debug_no_flood("DB_WARNING|".$database_session->err."|".$database_session->errstr."|".&database_clean_sql($sql)) }
		$database_session = $database_connection->prepare($sql);
		$database_session->execute;
		if ( $database_session->err ){
			if (exists &pbx_log_error_no_flood) { &pbx_log_error_no_flood("error_code=DB_FAIL|".$database_session->err."|".$database_session->errstr."|".&database_clean_sql($sql)) }
			return %output;
		}
	}
	#
	# run
	while ( $rows = $database_session->fetchrow_hashref(  ) ) {
		#warn Dumper($rows);
		$k = $rows->{$key};
		for (split ',', $rows_string) {
			$output{$k}{$_} = $rows->{$_};
		}
	}
	return %output;
}

sub database_select_as_hash(){
	#
	local ($sql,$rows_string)=@_;
	local (@rows,@rows_name,$i,%output);
	%output = ();
	@rows_name = split(/\,/,$rows_string);
	#
	unless (&database_check_connection()) {return %output}
	#
	$database_session = $database_connection->prepare($sql);
	$database_session->execute;
	if ( $database_session->err ){
		if (exists &pbx_log_debug_no_flood) { &pbx_log_debug_no_flood("DB_WARNING|".$database_session->err."|".$database_session->errstr."|".&database_clean_sql($sql)) }
		$database_session = $database_connection->prepare($sql);
		$database_session->execute;
		if ( $database_session->err ){
			if (exists &pbx_log_error_no_flood) { &pbx_log_error_no_flood("error_code=DB_FAIL|".$database_session->err."|".$database_session->errstr."|".&database_clean_sql($sql)) }
			return %output;
		}
	}
	#
	# run
	while ( @rows = $database_session->fetchrow_array(  ) ) {
		if ($rows_string eq "") {
			$output{(@rows)[0]}=(@rows)[1];
		} else {
			$i=0;
			foreach (@rows_name) {
				$output{(@rows)[0]}{$_} = (@rows)[$i+1];
				$i++;
			}
		}
	}
	return %output;
}

sub database_select_as_hash_with_auto_key(){
	#
	local ($sql,$rows_string)=@_;
	local (@rows,@rows_name,$i,%output,$line_id);
	%output = ();
	@rows_name = split(/\,/,$rows_string);
	#
	unless (&database_check_connection()) {return %output}
	#
	$database_session = $database_connection->prepare($sql);
	$database_session->execute;
	if ( $database_session->err ){
		if (exists &pbx_log_debug_no_flood) { &pbx_log_debug_no_flood("DB_WARNING|".&database_clean_sql($sql)) }
		$database_session = $database_connection->prepare($sql);
		$database_session->execute;
		if ( $database_session->err ){
			if (exists &pbx_log_error_no_flood) { &pbx_log_error_no_flood("error_code=DB_FAIL|".&database_clean_sql($sql)) }
			return %output;
		}
	}
	#
	$line_id = 0;
	while ( @rows = $database_session->fetchrow_array(  ) ) {
		$i=0;
		foreach (@rows_name) {
			$output{$line_id}{$_} = (@rows)[$i];
			$i++;
		}
		$line_id++;
	}
	return %output;
}
sub database_select_as_array(){
	#
	local ($sql,$rows_string)=@_;
	local (@rows,@rows_name,$i,@output);
	@rows_name = split(/\,/,$rows_string);
	@output = ();
	#
	unless (&database_check_connection()) {return @output}
	#
	$database_session = $database_connection->prepare($sql);
	$database_session->execute;
	if ( $database_session->err ){
		if (exists &pbx_log_debug_no_flood) { &pbx_log_debug_no_flood("DB_WARNING|".$database_session->err."|".$database_session->errstr."|".&database_clean_sql($sql)) }
		$database_session = $database_connection->prepare($sql);
		$database_session->execute;
		if ( $database_session->err ){
			if (exists &pbx_log_error_no_flood) { &pbx_log_error_no_flood("error_code=DB_FAIL|".$database_session->err."|".$database_session->errstr."|".&database_clean_sql($sql)) }
			return @output;
		}
	}
	#
	while ( @rows = $database_session->fetchrow_array(  ) ) {
		@output = ( @output , (@rows)[0] );
	}
	return @output;
}
sub database_do(){
	#
	local ($sql)=@_;
	local ($output);
	$output = -1;
	#
	unless (&database_check_connection()) {return $output}
	#
	$output = $database_connection->do($sql);
	if ($output eq "") {$output =-1;}
	return $output;
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
		if ($database_connection->do($sql)) {
			%hash = &database_select_as_hash("SELECT 1,LAST_INSERT_ID();");
			return $hash{1};
		} else {
			return "";
		}
	} else {
		return "";
	}
}
sub database_clean_sql(){
	local($sql,@values) = @_;
	local($tmp,$tmp1,$tmp2);
	$tmp1="\t"; $tmp2=" "; $sql =~ s/$tmp1/$tmp2/eg;
	$tmp1="\n"; $tmp2=" "; $sql =~ s/$tmp1/$tmp2/eg;
	$tmp1="\r"; $tmp2=" "; $sql =~ s/$tmp1/$tmp2/eg;
	$tmp = @values;
	if ($tmp>0) {
		$tmp--;
		foreach (0..$tmp) {
			$values[$_] = &database_escape($values[$_]);
		}
	}
	$tmp = sprintf($sql,@values);
	return  $tmp;
}
sub database_escape_sql(){
	local($sql,@values) = @_;
	local($tmp,$tmp1,$tmp2);
	$tmp1="\t"; $tmp2=" "; $sql =~ s/$tmp1/$tmp2/eg;
	$tmp1="\n"; $tmp2=" "; $sql =~ s/$tmp1/$tmp2/eg;
	$tmp1="\r"; $tmp2=" "; $sql =~ s/$tmp1/$tmp2/eg;
	$tmp = @values;
	if ($tmp>0) {
		$tmp--;
		foreach (0..$tmp) {
			$values[$_] = &database_escape($values[$_]);
		}
	}
	$tmp = sprintf($sql,@values);
	return  $tmp;
}
sub database_scape_sql(){ # todo: typo. :( need refactory code to dont use 
	local($sql,@values) = @_;
	local($tmp,$tmp1,$tmp2);
	$tmp1="\t"; $tmp2=" "; $sql =~ s/$tmp1/$tmp2/eg;
	$tmp1="\n"; $tmp2=" "; $sql =~ s/$tmp1/$tmp2/eg;
	$tmp1="\r"; $tmp2=" "; $sql =~ s/$tmp1/$tmp2/eg;
	$tmp = @values;
	if ($tmp>0) {
		$tmp--;
		foreach (0..$tmp) {
			$values[$_] = &database_escape($values[$_]);
		}
	}
	$tmp = sprintf($sql,@values);
	return  $tmp;
}
sub database_dump_all_queries_to_debug(){
	local($sql) = @_;
	# $$ pid / $0 me /
	$tmp1="\t"; $tmp2=" "; $sql =~ s/$tmp1/$tmp2/eg;
	$tmp1="\n"; $tmp2=" "; $sql =~ s/$tmp1/$tmp2/eg;
	$tmp1="\r"; $tmp2=" "; $sql =~ s/$tmp1/$tmp2/eg;
	open (DBDUMP,">>/tmp/zrdbdump.log");
	print DBDUMP "$$ | $0 | $sql\n";
	close(DBDUMP);
}
#------------------------
