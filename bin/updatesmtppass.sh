#!/bin/sh

echo "update v_default_settings set default_setting_value='$1' where  default_setting_subcategory='smtp_password'" | psql fusionpbx -U fusionpbx -h 127.0.0.1;
