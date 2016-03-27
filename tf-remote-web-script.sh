#!/bin/sh

yum install httpd -y

# create directory for helloz endpoint
httpdDir="/var/www/html"
hellozDir="$httpdDir/helloz"
hellozEndpoint="$hellozDir/index.html"
mkdir "$hellozDir"

printf "Instance: " > "$hellozEndpoint"

# convert "count.index" argument provided in .tf file to ASCII letter
# note: add 66 so that arg of 0 maps to B, 1 to C, etc...
numToASCII=$(($@ + 66))
printf \\$(printf '%03o' $numToASCII) >> "$hellozEndpoint"

# output public IP address for fun
echo " (`curl http://whatismyip.akamai.com/`)" >> "$hellozEndpoint"

cp /usr/lib/systemd/system/httpd.service /etc/systemd/system/httpd.service

systemctl enable /etc/systemd/system/httpd.service
systemctl start httpd.service
