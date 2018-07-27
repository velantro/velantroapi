#!/bin/sh

echo "Alter table v_voicemaildrop add column ext text default ''" | psql fusionpbx -U fusionpbx -h 127.0.0.1
