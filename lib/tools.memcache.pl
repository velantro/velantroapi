#!/usr/bin/perl
=pod
	Version 1.0
	Developed by Velantro inc
	Contributor(s):
	George Gabrielyan <george@velantro.com>
=cut


################################################################################
#
# memcache helpers
#
################################################################################
use Cache::Memcached;
use JSON;
$memcache = "";
return 1;
sub tools_memcache_init(){	
	$memcache = new Cache::Memcached {'servers' => ['127.0.0.1:11211'],};	
}
################################################################################



sub memcache_get_sql_uid(){
	local ($sql)=@_;
	return "DB".md5_hex($sql);
}
sub memcache_database_select_as_hash(){
	local($ttl,$sql,$rows_string)=@_;
	local(%output,$uid,$raw,$ref);
	%output = ();
	#
	# get sql_uid
	if ($sql eq "") {return %output}
	$uid = &memcache_get_sql_uid($sql);
	if ($uid eq "") {return %output}
	#
	# clean ttl seconds
	$ttl +=0;
	if ($ttl<1) {$ttl=1}
	if ($ttl>(60*60*24*30)) {$ttl=(60*60*24*30)}
	#
	# try read from memcache and return
	$raw = $memcache->get($uid);
	if (defined($raw)){
		$ref = JSON::from_json($raw);
		%output = %$ref;
		return %output
	}
	#
	# if fail, query database
	%output = &database_select_as_hash($sql,$rows_string);
	#
	# save answer at memecache
	$raw = JSON::to_json(\%output);
	$memcache->set($uid,$raw,$ttl);
	#
	# return 
	return %output
}

sub memcache_database_select_as_hash_with_auto_key(){
	local($ttl,$sql,$rows_string)=@_;
	local(%output,$uid,$raw,$ref);
	%output = ();
	#
	# get sql_uid
	if ($sql eq "") {return %output}
	$uid = &memcache_get_sql_uid($sql);
	if ($uid eq "") {return %output}
	#
	# clean ttl seconds
	$ttl +=0;
	if ($ttl<1) {$ttl=1}
	if ($ttl>(60*60*24*30)) {$ttl=(60*60*24*30)}
	#
	# try read from memcache and return
	$raw = $memcache->get($uid);
	if (defined($raw)){
		$ref = JSON::from_json($raw);
		%output = %$ref;
		return %output
	}
	#
	# if fail, query database
	%output = &database_select_as_hash_with_auto_key($sql,$rows_string);
	#
	# save answer at memecache
	$raw = JSON::to_json(\%output);
	$memcache->set($uid,$raw,$ttl);
	#
	# return 
	return %output
}

sub memcache_database_select_as_array(){
	local($ttl,$sql,$rows_string)=@_;
	local(@output,$uid,$raw,$ref);
	@output = ();
	#
	# get sql_uid
	if ($sql eq "") {return @output}
	$uid = &memcache_get_sql_uid($sql);
	if ($uid eq "") {return @output}
	#
	# clean ttl seconds
	$ttl +=0;
	if ($ttl<1) {$ttl=1}
	if ($ttl>(60*60*24*30)) {$ttl=(60*60*24*30)}
	#
	# try read from memcache and return
	$raw = $memcache->get($uid);
	if (defined($raw)){
		$ref = JSON::from_json($raw);
		@output = @$ref;
		return @output
	}
	#
	# if fail, query database
	@output = &database_select_as_array($sql);
	#
	# save answer at memecache
	$raw = JSON::to_json(\@output);
	$memcache->set($uid,$raw,$ttl);
	#
	# return 
	return @output
}
