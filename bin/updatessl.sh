#!/bin/sh

scp 134.velantro.net:/etc/dehydrated/certs/velantro.net/fullchain.pem /tmp
scp 134.velantro.net:/etc/dehydrated/certs/velantro.net/privkey.pem /tmp


scp -oPort=2222 /tmp/fullchain.pem sms.velantro.net:/etc/pki/tls/certs/fullchain.pem
scp -oPort=2222 /tmp/privkey.pem sms.velantro.net:/etc/pki/tls/private/privkey.pem
ssh -p 2222 sms.velantro.net 'service httpd restart'

scp /tmp/fullchain.pem manage.velantro.net:/etc/pki/tls/certs/
scp /tmp/privkey.pem manage.velantro.net:/etc/pki/tls/private/

ssh manage.velantro.net 'service httpd restart'



