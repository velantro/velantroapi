use Net::WebSocket::Server;
use IO::Socket::SSL;
use Net::AMQP::RabbitMQ;
require "/usr/local/pbx/bin/default.include.pl";

use LWP::Simple;

%sms_connections = ();
my $mq = Net::AMQP::RabbitMQ->new();
$mq->connect("localhost", { user => "guest", password => "guest" });
$mq->channel_open(1);
$mq->queue_declare(1, "incoming");

%incoming_connection = ();
$ssl_server = IO::Socket::SSL->new(
  Listen        => 5,
  LocalPort     => 8443,
  Proto         => 'tcp',
  SSL_cert_file => '/etc/ssl/certs/nginx.crt',
  SSL_key_file  => '/etc/ssl/private/nginx.key',
) or die "fail to create ssl";

Net::WebSocket::Server->new(
    #listen => 8088,
    listen => $ssl_server,
    on_connect => sub {
        my ($serv, $conn) = @_;
        warn "Get connection from " . $conn->ip() . "\n";
        $conn->on(
            utf8 => sub {
                my ($conn, $msg) = @_;
                warn "Get MSG: $msg";
               
                $conn->send_utf8($msg);
                %hash = &Json2Hash($msg);
                $action = $hash{action} || '';
                unless ($hash{action} && $hash{agent} && $hash{domain_name}) {
                	warn "Reply failed action!\n";
                	$conn->send_utf8(&Hash2Json('status' => 0, 'message' => 'unknown msg'));
                	return;
                }
                
                %result = ();
                if ($action eq 'login') {
                	$uuid = &genuuid();
                	$old_uuid = &check_connection($conn);
                	if ($old_uuid) {
                		delete $incoming_connections{$old_uuid};
                	}
                	
                	$incoming_connections{$uuid}{conn} = $conn;
                	$incoming_connections{$uuid}{agent} = $hash{agent};
                	$incoming_connections{$uuid}{domain_name} = $hash{domain_name};
                	$result{status} = '1';
			
                	$result{message} = "$action  ok!";
                	

                }
	            $str = &Hash2Json(%result);
	            warn "Reply: $str";
	            $conn->send_utf8($str);
            },
            disconnect => sub {
            	local ($connection, $code, $reason) = @_;
            	$uuid = &check_connection($connection);
            	if ($uuid) {
            		delete $incoming_connections{$uuid};
            	}
            	
            }
        );
    },
   	tick_period => 1,
    on_tick => \&check_incoming_event,
)->start;

sub check_incoming_event () {
	($serv) = @_;
	$msg = $mq->get(1, "incoming");
  	print "GET NEW MSG: " . $msg->{body} . "\n" if $msg->{body};
  	$event_str = $msg->{body};
  	
		local %hash = &Json2Hash($event_str);
		for $uuid (keys %incoming_connections) {
			if ((($hash{from} eq $incoming_connections{$uuid}{agent}) ||
				($hash{to} eq $incoming_connections{$uuid}{agent})) &&
				$hash{domain_name} eq $incoming_connections{$uuid}{domain_name}) {
					$conn = $incoming_connections{$uuid}{conn};
					print "send $event_str to " . $conn->ip() . ':' . $conn->port(). " ... \n";
					$conn->send_utf8($event_str) if $event_str;
			}
   	}
    
}

sub check_connection () {
	local ($connection) = @_;
	for $uuid (keys %incoming_connections) {
		if ($incoming_connections{$uuid}{conn} == $connection) {
			return $uuid;
		}
	}
}