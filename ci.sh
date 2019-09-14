#!/bin/sh -xe

# This file is part of nss-tls.
#
# Copyright (C) 2018, 2019  Dima Krasner
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

meson --prefix=/usr --buildtype=release -Dstrip=true build
ninja -C build install

meson configure build -Dcache=false
ninja -C build

CC=clang meson --prefix=/usr -Dresolvers=1.1.1.1/dns-query,9.9.9.9:5053/dns-query,dns.google/resolve -Db_sanitize=address build-asan
ninja -C build-asan nss-tlsd

ldconfig
cp -f /etc/nsswitch.conf /tmp/
sed 's/hosts:.*/hosts: files tls/' -i /etc/nsswitch.conf
echo '8.8.8.8 dns.google' >> /etc/hosts
G_MESSAGES_DEBUG=all ./build-asan/nss-tlsd &
pid=$!
sleep 1

valgrind --leak-check=full --track-fds=yes --error-exitcode=1 tlslookup ipv4.google.com
valgrind --leak-check=full --track-fds=yes --error-exitcode=1 tlslookup ipv6.google.com
valgrind --leak-check=full --track-fds=yes --error-exitcode=1 tlslookup google.com
valgrind --leak-check=full --track-fds=yes --error-exitcode=1 tlslookup baidu.com

getent hosts ipv4.google.com
getent hosts ipv6.google.com
getent hosts google.com
getent hosts baidu.com

kill $pid
sleep 1
