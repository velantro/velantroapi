#/bin/sh

mon=$1;
emon=$2
echo "select sum(billsec) from v_xml_cdr where start_stamp >= '$mon 00:00:00' and start_stamp <= '$emon 23:59:59' and (from_did like '800%' or from_did like '811%' or from_did like '822%' or from_did like '833%' or from_did like '844%' or from_did like '855%'  or from_did like '866%'or from_did like '877%' or from_did  like '888%' or from_did like '899%' or from_did like '1800%' or from_did like '1811%' or from_did like '1822%' or from_did like '1833%' or from_did like '1844%' or from_did like '1855%'  or from_did like '1866%'or from_did like '1877%' or from_did  like '1888%' or from_did like '1899%')" | psql fusionpbx -U fusionpbx -h 127.0.0.1