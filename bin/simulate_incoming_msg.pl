#!/usr/bin/perl

use Net::AMQP::RabbitMQ;
my $mq = Net::AMQP::RabbitMQ->new();
$mq->connect("localhost", { user => "guest", password => "guest" });
$mq->channel_open(1);
$mq->queue_declare(1, "incoming");
$json = '{"domain_name":"134.velantro.net","calluuid":"ef139eea-0a5c-4da9-b027-8faa9eef26ca","from":"17474779513","callaction":"bridge","did":"18186968805","calltype":"extension","to":"109","starttime":"2020-09-03 05:17:50"}';
warn "Send Event: $json\n";
$mq->publish(1, "incoming", $json);
