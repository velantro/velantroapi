$file = "/tmp/firewall_need_update";
if (-e $file)  {
    unlink $file;
    system ("perl /salzh/bin/acmd.pl 'updatefirewall'");
} else {
    print "No need update!!!\n";
}
