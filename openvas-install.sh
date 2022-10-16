#!/bin/sh

set -e

LOCATION=Vienna
CITY=Vienna
COUNTRY=AT
COMPANY=Company
DEPARTMENT="IT Department"
DOMAIN=openvas
PYVER=py39

PSQL_VERSION=13

echo Installing prerequisites.
pkg install -y pwgen

echo OpenVAS installation started.
echo Please provide the following system specific credentials for setup.
echo Choose unique passwords, which are not used in any other system or
echo application. Leave replies empty to generate random secrets.
echo ""
echo -n "DATABASE user gvm:  "
read POSTGRES_GVM

if [ "x" == "x${POSTGRES_GVM}" ]; then
	POSTGRES_GVM=$(pwgen 32 -1)
fi

echo -n "WEB user admin:     "
read USER_ADMIN

if [ "x" == "x${USER_ADMIN}" ]; then
	USER_ADMIN=$(pwgen 12 -1)
fi

echo This installation is automated and does not require any further user 
echo interaction but it will take a while to complete...
echo ""

echo PREREQS
echo Installing prerequisite utilities.
pkg install -y git py39-cython libxslt py39-lxml py39-paramiko bison cmake-core \
	ninja pkgconf gvm-libs libpcap net-snmp json-glib rsync nmap py39-impacket
cd /usr/ports
git clone --depth 1 --branch 2022Q4 https://git.freebsd.org/ports.git /usr/ports

echo DATABASE
echo Installing postgresql database.
set +e
pkg info | grep postgresql${PSQL_VERSION} > /dev/null
if [ "0" != "$?" ]; then
	set -e
	pkg install -y postgresql${PSQL_VERSION}-server postgresql${PSQL_VERSION}-contrib
	echo Initializing database.
	sysrc postgresql_enable=YES
	service postgresql initdb
	service postgresql start
	echo Setting up database and database user
	su -l postgres -c "createuser gvm"
	su -l postgres -c "psql -c \"ALTER USER postgres WITH PASSWORD '${POSTGRES_GVM}';\""
	su -l postgres -c "createdb -E utf8 -O gvm gvmd"
	su -l postgres -c "psql -c \"create extension \\\"uuid-ossp\\\";\" gvmd"
	su -l postgres -c "psql -c \"create extension \\\"pgcrypto\\\";\" gvmd"
	su -l postgres -c "psql -c \"create role dba with superuser noinherit;\" gvmd"
	su -l postgres -c "psql -c \"grant dba to gvm;\" gvmd"
else
	echo Database already installed.
	set -e
fi

echo INFRASTRUCTURE
echo Installating redis.
set +e
redis_pid=$(pgrep redis)
if [ "" == "$redis_pid" ]; then
	set -e
	pkg install -y redis
	sysrc redis_enable=YES
	#chown gvm:gvm /var/log/redis/redis.log
else
	echo Redis already installed and running.
	set -e
fi

sysrc redis_user=root
chown -R root:redis /var/db/redis
# increase database count
sed -i '' 's@databases 16@databases 32@g' /usr/local/etc/redis.conf
set +e
cat /usr/local/etc/redis.conf | grep /tmp/redis.sock > /dev/null
if [ "0" != "$?" ]; then
	cat >> /usr/local/etc/redis.conf <<EOF
unixsocket /tmp/redis.sock
unixsocketperm 770
EOF
fi
set -e

if [ "" == "$redis_pid" ]; then
	service redis start
else
	service redis restart
fi

echo OPENVAS APPLICATION
echo Installing openvas scanner.
# Package currently unavailable - we are moving to ports
#pkg install -y py38-ospd-openvas openvas
cd /usr/ports/security/py-ospd-openvas
make install

echo Installing greenbone security assistant.
pkg install -y gvm gvm-libs gvmd ${PYVER}-gvm-tools ${PYVER}-python-gvm gsad
echo Update openvas config
set +e
cat /usr/local/etc/openvas/openvas.conf | grep db_address > /dev/null
if [ "0" != "$?" ]; then
	echo db_address = /tmp/redis.sock >> /usr/local/etc/openvas/openvas.conf
fi
set -e
echo Setting up openvas server certificates.
mkdir -p /var/lib/gvm/CA
mkdir -p /var/lib/gvm/private/CA
# workaround to fix root issue
sysrc ospd_openvas_user=root
# scanning issue workaround
set +e
cat /usr/local/etc/openvas/openvas.conf | grep test_alive > /dev/null
if [ "0" != "$?" ]; then
	echo "test_alive_hosts_only = no" >> /usr/local/etc/openvas/openvas.conf
fi
set -e

# Add user gvm to redis group
pw groupmod redis -M gvm

# Create self signed certificate first
if [ ! -e /var/lib/gvm/private/CA/serverkey.pem ]; then
	openssl req -x509 -nodes -newkey rsa:4096 -keyout /var/lib/gvm/private/CA/serverkey.pem -out /var/lib/gvm/CA/servercert.pem \
	        -sha256 -days 365 \
	        -subj "/C=${COUNTRY}/ST=${CITY}/L=${LOCATION}/O=${ORGANIZATION}/OU=${DEPARTMENT}/CN=${DOMAIN}"
	chown gvm:gvm /var/lib/gvm/CA/servercert.pem /var/lib/gvm/private/CA/serverkey.pem
	chmod 400 /var/lib/gvm/private/CA/serverkey.pem
fi

echo Setting up GPG repository
cd /var/lib/gvm/gvmd/gnupg
gpg --homedir /var/lib/gvm/gvmd/gnupg/ --list-keys
chown -R gvm:gvm /var/lib/gvm/gvmd/gnupg
mkdir -p /var/lib/gvm/cert-data
mkdir -p /var/lib/gvm/data-objects/gvmd
mkdir -p /var/lib/gvm/scap-data
chown -R gvm:gvm /var/lib/gvm

sysrc gsad_enable=YES
sysrc gvmd_enable=YES
sysrc ospd_openvas_enable=YES
# Populate database
su -m gvm -c "gvmd -m"
# Create admin user
set +e
ADMIN_UUID=$(su -m gvm -c "gvmd --get-users -v" | grep admin|awk '{print $2}')
set -e
if [ "" != "${ADMIN_UUID}" ]; then
	echo admin user already exists. Not creating.
else
	su -m gvm -c "gvmd --create-user=admin --password=${USER_ADMIN}"
fi
ADMIN_UUID=$(su -m gvm -c "gvmd --get-users -v" | grep admin|awk '{print $2}')
su -m gvm -c "gvmd --modify-setting 78eceaec-3385-11ea-b237-28d24461215b --value ${ADMIN_UUID}"

# synchronize feeds
su -m gvm -c "greenbone-feed-sync --type GVMD_DATA"
su -m gvm -c "greenbone-scapdata-sync"
su -m gvm -c "greenbone-certdata-sync"
su -m gvm -c "cd /tmp && greenbone-nvt-sync"

# patch gvmd rc script
set +e
cat /usr/local/etc/rc.d/gvmd | grep PATH > /dev/null
if [ "0" != "$?" ]; then
	sed -i '' '/gvmd.pid/a\
export PATH=/usr/local/bin:/usr/local/sbin:$PATH
' /usr/local/etc/rc.d/gvmd
fi
set -e

# start services
service gvmd start
service gsad start
service ospd_openvas start

echo
echo SUMMARY
echo The following secrets were applied during installation. Please store
echo them in a save place:
echo
echo DATABASE user gvm: ${POSTGRES_GVM}
echo WEB user admin:    ${USER_ADMIN}

