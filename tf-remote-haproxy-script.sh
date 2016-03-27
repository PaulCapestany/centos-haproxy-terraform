#!/bin/sh

yum install haproxy -y

echo "
#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
    # to have these messages end up in /var/log/haproxy.log you will
    # need to:
    #
    # 1) configure syslog to accept network log events.  This is done
    #    by adding the '-r' option to the SYSLOGD_OPTIONS in
    #    /etc/sysconfig/syslog
    #
    # 2) configure local2 events to go to the /var/log/haproxy.log
    #   file. A line like the following can be added to
    #   /etc/sysconfig/syslog
    #
    #    local2.*                       /var/log/haproxy.log
    #
    log         127.0.0.1 local2

    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4000
    user        haproxy
    group       haproxy
    daemon

    # turn on stats unix socket
    stats socket /var/lib/haproxy/stats

#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will
# use if not designated in their block
#---------------------------------------------------------------------
defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          1m
    timeout server          1m
    timeout http-keep-alive 10s
    timeout check           10s
    maxconn                 3000

#---------------------------------------------------------------------
# frontend which proxys to the backends
#---------------------------------------------------------------------
frontend http_front
   bind *:80
   stats uri /stats
   default_backend http_back

   # !!!: normally you would not want to expose this, only for demo
   # this allows anyone to easily take backends down/up/etc via panel
   stats admin if TRUE

#---------------------------------------------------------------------
# round robin balancing between the various backends
#---------------------------------------------------------------------
backend http_back
    balance     roundrobin
" > /etc/haproxy/haproxy.cfg

cp /usr/lib/systemd/system/haproxy.service /etc/systemd/system/haproxy.service

systemctl enable /etc/systemd/system/haproxy.service
systemctl start haproxy.service
