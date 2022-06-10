#!/bin/sh

pass=FlagNot2017!

echo "update v_default_settings set default_setting_value='$pass' where  default_setting_subcategory='smtp_password'" | psql fusionpbx -U fusionpbx -h 127.0.0.1;
echo "select default_setting_value from v_default_settings where  default_setting_subcategory='smtp_password'" | psql fusionpbx -U fusionpbx -h 127.0.0.1;

echo "update v_default_settings set default_setting_value='notification@flagmantelecom.com' where  default_setting_subcategory='smtp_from'" | psql fusionpbx -U fusionpbx -h 127.0.0.1;
echo "update v_default_settings set default_setting_value='notification@flagmantelecom.com' where  default_setting_subcategory='fax_smtp_from'" | psql fusionpbx -U fusionpbx -h 127.0.0.1;

echo "update v_default_settings set default_setting_value='notification@flagmantelecom.com' where  default_setting_subcategory='smtp_username'" | psql fusionpbx -U fusionpbx -h 127.0.0.1;

echo "update v_default_settings set default_setting_value='Notification | Flagman Telecom' where  default_setting_subcategory='smtp_from_name'" | psql fusionpbx -U fusionpbx -h 127.0.0.1;

echo "update v_default_settings set default_setting_value='Notification | Flagman Telecom' where  default_setting_subcategory='fax_smtp_from_name'" | psql fusionpbx -U fusionpbx -h 127.0.0.1;

echo "update v_default_settings set default_setting_value='smtp-relay.gmail.com:465' where  default_setting_subcategory='smtp_host'" | psql fusionpbx -U fusionpbx -h 127.0.0.1;


echo "update v_default_settings set default_setting_value='ssl' where  default_setting_subcategory='smtp_secure'" | psql fusionpbx -U fusionpbx -h 127.0.0.1;

echo "update v_default_settings set default_setting_value='465' where  default_setting_subcategory='smtp_port'" | psql fusionpbx -U fusionpbx -h 127.0.0.1;

#luarun email.lua zhongxiang721@163.com notification@flagmantelecom.com ' ' 'hi' 'hi test22'