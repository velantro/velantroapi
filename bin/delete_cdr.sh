#!/bin/sh

echo "delete  from v_xml_cdr where  start_stamp < CURRENT_DATE - INTERVAL '6 months' order by start_stamp desc limit 10;" | psql fusionpbx -U fusionpbx -h 127.0.0.1