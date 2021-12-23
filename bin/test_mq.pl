#!/usr/bin/perl
#======================================================
# load head
#======================================================
use IO::Socket;
use Switch;
use Data::Dumper;
use DBI;
use Time::Local;
#use Math::Round qw(:all);
use URI::Escape;
use Net::AMQP::RabbitMQ;
use POSIX qw(strftime);
use MIME::Base64;
require "/usr/local/pbx/bin/default.include.pl";

#======================================================


#======================================================
# config
#======================================================
$conference_host 	= $host_name;
$version 			= "1.0.2";
$debug 				= 0;
$fork 				= 0;
$file_pid 			= "/var/run/app_konference.pid";
$file_log 			= "/tmp/app_konference.log";
$file_log_bkp 		= "/tmp/app_konference.log.bkp";
$host 				= "127.0.0.1";
$port 				= 8021;
$user 				= "dispatchevent";
$secret 			= "dispatch123"; 
$EOL 				= "\015\012";
$BLANK 				= $EOL x 2;
%dtmf_buffer 		= ();
%automute_buffer	= ();
%poll_buffer		= ();
%buffer 			= ();
$default_host = '115.28.137.2';
$host_prefix  = '';

my $mq = Net::AMQP::RabbitMQ->new();
$mq->connect("localhost", { user => "guest", password => "guest" });
$mq->channel_open(1);
$mq->queue_declare(1, "incoming");
$json = '{"call_state":"DOWN","call_center_queue_uuid":"501f5927-ed79-49eb-b33b-37248c11d79f","to":"997","queue":"501f5927-ed79-49eb-b33b-37248c11d79f","caller_destination":"8883126498","domain_name":"134.velantro.net","starttime":"2021-12-23 02:11:19","from":"7474779513","calltype":"queue","callaction":"dial","calluuid":"14291c51-6ce8-4ca8-a2c7-becd1ddda695"}';

#$cmd = "curl -d 'callerid1=$from&callerid2=$to&callerIdNumber=$from&requestUrl=agi%3A%2F%2F115.28.137.2%2Fincoming.agi&context=from-internal&channel=SIP%2Fa2b-000007b0&vtigersignature=1940898792584673c6e9a8a&callerId=$from&callerIdName=$from&event=AgiEvent&type=SIP&uniqueId=1481543422.1968&StartTime=$now&callUUID=$uuid&callstatus=StartApp' http://$host/vtigercrm/modules/PBXManager/callbacks/PBXManager.php";
warn "Send Event: $json\n";
$mq->publish(1, "incoming", $json);
#warn $cmd;