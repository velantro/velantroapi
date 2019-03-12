
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
$outfile = shift || "/tmp/tds.csv";
if (!-e $outfile) {
   print "USDOT,COMPANY,EMAIL,PHONE,PERSON\n";
}

open OUT, ">> $outfile";

while (1) {
 
   $last_start = `cat $tds_start_file`;
   $start = $last_start || 0;
   $length = 10;
   $url    = "https://tdsource.com/k/rest/v1/search?access_token=$config{tds_access_key}&pretty=true";
   #$criteria = "start=0&length=$length";
   
   
   $response = &do_request("search", "start=$start&length=100");
   if ($response && $response->{status}{status_code} eq '200') {
      $hash = decode_json $raw;
      if ($hash->{status}{status_code} ne '200') {
         warn "Warn: " . $hash->{status}{status_code} . " : " .  $hash->{status}{message};
      } else {
         warn "Fetch $start/" . $hash->{results}{matched_records} . "!\n";
      }
      
      for $i (0..$length-1) {
         local %ref = %{$hash->{results}{searchResults}[$i]};
         local %carrier = ();
         $carrier{dot} = $ref{DOT};
         ($carrier{name} = $ref{Name}) =~ s/[,']//;
         
         #print "$ref{DOT},$ref{Name},";
         $response = &do_request("carrier/$carrier{dot}");
         if ($response && $response->{status}{status_code} eq '200') {
            $carrier{phone} = $response->{results}{contact_phone};
            $carrier{email} = $response->{results}{contact_email};
            ($carrier{person} = $response->{results}{company_rep1}) =~ s/[,']//;
         }
         
         print OUT "$carrier{dot},$carrier{name},$carrier{email},$carrier{phone},$carrier{person}\n";
         open W, "> $tds_start_file";
         print W $start+$i+1;
         close W;
      }
   }

}
sub connect_db() {
    local ($type, $adb, $ahost, $auser, $apass) = @_;
    $type  ||= $config{dbtype};
    $adb   ||= $config{dbname};
    $ahost ||= $config{dbhost};
    $auser ||= $config{dbuser};
    $apass ||= $config{dbpass};
    local $dbh;
	if ($type eq 'sqlite') {
    $dbh = DBI->connect("dbi:SQLite:dbname=$adb","","");
	} elsif($type eq 'pg') {
		$dbh = DBI->connect("DBI:Pg:database=$adb;host=$ahost", "$auser", "$apass", {RaiseError => 0, AutoCommit => 1});
	} else {
		$dbh = DBI->connect("DBI:mysql:database=$adb;host=$ahost", "$auser", "$apass", {RaiseError => 0, AutoCommit => 1});
		
	}

	if (!$dbh) {
        print 'internal error: fail to login db';
        exit 0;
	}
    
    return $dbh;
}

sub do_request {
   $path = shift;
   $data = shift;
   return if !$url;
   
   warn "Query $path!\n";
   $raw =  `curl -s -d \"$data\" \"https://tdsource.com/k/rest/v1/$path?access_token=$config{tds_access_key}&pretty=true\"`;
   if (!$raw) {
      warn "Fail to get response for $path!\n";
      return;
   }
   
   local $hash = decode_json $raw;
   if ($hash->{status}{status_code} ne '200') {
      warn "Get Error:[" . $hash->{status}{status_code} . "]: ". $hash->{status}{message} . "!\n";
   }
   
   return $hash;   
}
