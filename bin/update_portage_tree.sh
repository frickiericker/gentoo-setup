#!/bin/sh -efu
set -efu
export LANG=C LC_ALL=C
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
emaint sync --all
eix-update
emerge --fetchonly -uDN @world
