
=pod
USDOT #
company name
email
phone number 
contact person name
=cut

use DBI;
use JSON;
use Data::Dumper;

$out = `ps aux | grep $0 | grep -v 'grep ' | wc -l`;
chomp $out;
$debug = shift;
if ($out > 1) {
    warn "another $0 is already running, quit! ...";
    exit 0;
}
my %config = ();
my $txt = `cat /etc/fb.conf`;

for (split /\n/, $txt) {
    my ($key, $val)     = split /=/, $_, 2;

    if ($key) {
        $config{$key} = $val;
        warn "$key=$val\n";
    }
}

$tds_start_file = "/etc/tds_start";
$json = JSON->new->allow_nonref;
$outfile = shift || "/var/www/fusionpbx/tds.csv";
if (!-e $outfile) {
   print "USDOT,STATE,COMPANY,EMAIL,PHONE,PERSON\n";
}

open OUT, ">> $outfile";
$cookie = "/tmp/tds.txt";
&do_login() or exit;
$tds_start_file = "/etc/tds_start";

$last_start = `cat $tds_start_file`;
$last_start =~ s/\D//g;
$start = $last_start || 0;

$length = 10;
%email_spool = ();
&init_email_spool;


while (1) {    
    $result = &do_search($start);
    #print Data::Dumper::Dumper($result);
    $data = $result->{aaData};
    $total ||= $result->{iTotalDisplayRecords};
            #warn $detail, "\n==========\n\n";
    warn "start fetch $start / $total\n";
    if (int(@$data) < 1) {
        &do_login();
    }
    
    #print Data::Dumper::Dumper($data);
    for $d (@$data) {
        #print join "\n", @$d, "\n";
        ($url) = $$d[0] =~ m/(https:.+)"/;
        ($dot) = $url =~ m{/(\d+)\?};
        ($city,$state,$country) = split ', ', $$d[2];
        ($name = $$d[1]) =~ s/[,']/ /g;
        $html =  &do_request($url);
        ($detail) = $html =~ m{<div id='textSummary' class="pull-left">(.+?)</div>}s;
        ($phone,$left) = $detail =~ m{(\(\d\d\d\) \d\d\d\-\d\d\d\d)(.+)}s;
        $phone =~ s/\D//g;
        ($email) = $left =~ m{mailto:(.+?)['"]}s;
        ($person) = $left =~ m{field'></a><br>\s+?(\w[\s\w,']+\w)\s+<br>}s;
        $person =~ s/[,']/ /g;
        next unless $email;
        $email_result = &validate_email($email);
        if (!$email_result || $email_result->{status} ne 'deliverable') {
            warn "Validate Email $email: " .  $email_result->{message}. "!\n";
            next;
        }
        $email_spool{lc($email)} = 1;
        $line = "$dot,$state,$name,$email,$phone,$person";
        print $line, "\n";
        print OUT $line. "\n";
        open W, "> $tds_start_file";
        print W ++$start;
        close W;
    }
    #$start += $length;

}

sub do_login {
    $response = `curl -k  -s -d \"login=$config{tds_user}&password=$config{tds_pass}\" -c $cookie \"https://tdsource.com/k/cpcanon/login\"`;
    if ($response =~ /Enter your login credentials to access Transportation Data Source/) {
        warn "fail to login tds!!\n";
        warn $response;
    }
    return 1;
}

sub do_search {
    $start = shift || 0;
    $raw = `curl  -s -k -b $cookie \"https://tdsource.com/k/cpcrest/dtsearch?cpc_search_id=3307605&sEcho=2&iColumns=5&sColumns=%2C%2C%2C%2C&iDisplayStart=$start&iDisplayLength=$length&mDataProp_0=0&sSearch_0=&bRegex_0=false&bSearchable_0=true&bSortable_0=true&mDataProp_1=1&sSearch_1=&bRegex_1=false&bSearchable_1=true&bSortable_1=true&mDataProp_2=2&sSearch_2=&bRegex_2=false&bSearchable_2=true&bSortable_2=true&mDataProp_3=3&sSearch_3=&bRegex_3=false&bSearchable_3=true&bSortable_3=false&mDataProp_4=4&sSearch_4=&bRegex_4=false&bSearchable_4=true&bSortable_4=true&sSearch=&bRegex=false&iSortingCols=0&_=1552372825677\"`;
    
    if (!$raw) {
      warn "Fail to get response for $path!\n";
      return;
   }
   #warn $raw;
   local $hash = decode_json $raw;
   
   return $hash;   
}
sub do_request {
    $url = shift;
    warn "fetch $url!\n";
    return if !$url;
    
    $raw =  `curl -s -k -b $cookie  \"$url\"`;
   
   return $raw;
}

sub validate_email2 {
    local $email = shift || return;
    
    local $raw = `curl  -s -k  \"https://hunter.io/trial/v2/email-verifier?email=$email&format=json\"`;
    
    if (!$raw) {
        warn "Fail to get response for $path!\n";
        return;
    }
    
    local $hash =  decode_json $raw;
    return $hash;
}

sub validate_email {
    use Data::Validate::Email qw(is_email is_email_rfc822);
    use Net::DNS;
    local $email = shift || return;
    local ($user, $host) = split '@', $email;
    if ($email_spool{$email}) {
        return {status => 'undeliverable', message => $email . " already existed in spool"};
    }
    
    unless (is_email($email) or is_email_rfc822($email)) {
         return {status => 'undeliverable', message => 'not pass email format checker'};
    }
    
    @mx = mx($host);
    if (int(@mx) < 1) {
        return {status => 'undeliverable', message => "not found MX records by host=$host"};
    }
    
    return {status => 'deliverable'};
}

sub init_email_spool {
    open TDS, $outfile;
    while (<TDS>) {
        chomp;
        local @f = split ',', $_, 6;
        $email_spool{lc($f[3])} = 1;
        $i++;
    }
    warn "$i emails in total!\n";
    close TDS;
}