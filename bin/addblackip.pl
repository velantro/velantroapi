$ip = shift;

system("iptables -I INPUT 1   -s  $ip -j DROP");

