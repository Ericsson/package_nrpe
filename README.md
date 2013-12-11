package_nrpe
============

Scripts to build and package nrpe

Verified on:

EL 5 32bit
EL 5 64bit
EL 6 32bit
EL 6 64bit
SLEx 10 32bit
SLEx 10 64bit
SLEx 11 32bit
SLEx 11 64bit
Solaris  8 sparc
Solaris  9 sparc 
Solaris 10 sparc
Solaris 11 sparc
Solaris 10 x86
Solaris 11 x86
Ubuntu 12.04 LTS 64bit

Build
=====
be root on <server>
uninstall previous package and remove /opt/op5
http_proxy=<your proxy:port>
https_proxy=<your proxy:port>
copy the repo to /tmp/
cd /tmp/package_nrpe/
./build-nrpe-2.15.sh
