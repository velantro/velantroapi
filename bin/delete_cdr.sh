#!/bin/sh

echo "delete  from v_xml_cdr where  start_stamp < CURRENT_DATE - INTERVAL '6 months'" | psql fusionpbx -U fusionpbx -h 127.0.0.1