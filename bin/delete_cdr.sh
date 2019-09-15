#!/bin/sh

#echo "00 4 * * 0 root /var/www/api/bin/delete_cdr.sh" >> /etc/crontab

echo "delete  from v_xml_cdr where  start_stamp < CURRENT_DATE - INTERVAL '6 months' and domain_name != 'rapidins.velantro.net'" | psql fusionpbx -U fusionpbx -h 127.0.0.1