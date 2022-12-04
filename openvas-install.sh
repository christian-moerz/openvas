#!/bin/sh

#
# Licensed under BSD license
# 2019/10/29 - update thx to sn3ak; fixed ORG/COMPANY / issue 1

set -e

LOCATION=Vienna
CITY=Vienna
COUNTRY=AT
COMPANY=Company
DEPARTMENT="IT Department"
DOMAIN=openvas
PYVER=py39
PORTBRANCH=2022Q4
GBKEY=https://www.greenbone.net/GBCommunitySigningKey.asc
PSQL_VERSION=13

BPATH=$(dirname $0)
cd ${BPATH}
BPATH=$(pwd)

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
	ninja pkgconf gvm-libs libpcap net-snmp json-glib rsync nmap py39-impacket \
	py39-urllib3 mosquitto pg-gvm p5-XML-Parser wget xmlstarlet autoconf \
	automake sshpass socat zip samba412 libmicrohttpd
cd /usr/ports
if [ ! -e /usr/ports/.git ]; then
	git clone --depth 1 --branch ${PORTBRANCH} https://git.freebsd.org/ports.git /usr/ports
fi

set +e
cat /etc/make.conf | grep WRKDIRPREFIX > /dev/null
if [ "0" != "$?" ]; then
        echo "WRKDIRPREFIX?= /usr/ports/build" >> /etc/make.conf
fi
if [ ! -e /usr/ports/build ]; then
        mkdir -p /usr/ports/build
fi
set -e

echo DATABASE
echo Installing postgresql database.
set +e
pkg info | grep postgresql${PSQL_VERSION}-server > /dev/null
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
	su -l postgres -c "psql -c \"create extension \\\"pg-gvm\\\";\" gvmd"
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
set +e
pkg info | grep ospd-openvas > /dev/null
if [ "0" != "$?" ]; then
	set -e
	make install
fi
set -e
cd /usr/ports/security/py-notus-scanner
set +e
pkg info | grep notus-scanner > /dev/null
if [ "0" != "$?" ]; then
	set -e
	make install
fi
set -e

set +e
pkg info | grep gsad > /dev/null
if [ "0" != "$?" ]; then
	set -e
	cd /usr/ports/security/gsad
	echo Patching gsad.
		cp ${BPATH}/patch/patch-src_gsad.c /usr/ports/security/gsad/files
	make install
fi
set -e

set +e
echo Checking gvmd installation.
pkg info | grep gvmd > /dev/null
if [ "0" != "$?" ]; then
	set -e
	echo Patching gvmd.
	#rm /usr/ports/security/gvmd/files/*
	#cp ${BPATH}/patch/gvmd/* /usr/ports/security/gvmd/files
	cd /usr/ports/security/gvmd
	make install
	echo Exit code $?
else
	echo gvmd already installed. Skipping.
fi
set -e

echo Configure Notus scanner.
echo "[notus-scanner]" > /usr/local/etc/gvm/notus-scanner.toml
echo 'mqtt-broker-address = "localhost"' >> /usr/local/etc/gvm/notus-scanner.toml
echo 'mqtt-broker-port = "1883"' >> /usr/local/etc/gvm/notus-scanner.toml
echo 'products-directory = "/var/lib/openvas/plugins/notus/products"' >> /usr/local/etc/gvm/notus-scanner.toml
echo 'log-level = "INFO"' >> /usr/local/etc/gvm/notus-scanner.toml
echo "disable-hashsum-verification = false" >> /usr/local/etc/gvm/notus-scanner.toml

set +e
cat /etc/devfs.conf | grep bpf > /dev/null
set -e
if [ "0" != "$?" ]; then
	echo Fixing devfs configuration for gvm
	echo <EOF >> /etc/devfs.conf
   own     bpf     root:gvm
   perm    bpf     0660
EOF
service devfs restart
fi

echo Installing greenbone security assistant.
pkg install -y ${PYVER}-gvm-tools ${PYVER}-python-gvm openvas
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
	        -subj "/C=${COUNTRY}/ST=${CITY}/L=${LOCATION}/O=${COMPANY}/OU=${DEPARTMENT}/CN=${DOMAIN}"
	chown gvm:gvm /var/lib/gvm/CA/servercert.pem /var/lib/gvm/private/CA/serverkey.pem
	chmod 400 /var/lib/gvm/private/CA/serverkey.pem
fi

echo Setting up GPG repository
cd /var/lib/gvm/gvmd/gnupg
fetch -o GB.asc https://www.greenbone.net/GBCommunitySigningKey.asc
gpg --homedir /var/lib/gvm/gvmd/gnupg/ --list-keys
gpg --homedir /var/lib/gvm/gvmd/gnupg/ --import GB.asc
chown -R gvm:gvm /var/lib/gvm/gvmd/gnupg
mkdir -p /var/lib/gvm/cert-data
mkdir -p /var/lib/gvm/data-objects/gvmd
mkdir -p /var/lib/gvm/scap-data
chown -R gvm:gvm /var/lib/gvm

echo Configure and integrate mosquitto.
echo "mqtt_server_uri = localhost:1883" >> /usr/local/etc/openvas/openvas.conf

# make sure gvmd isn't running already
set +e
ps ax |grep gvmd > /dev/null
if [ "0" == "$?" ]; then
	service gvmd onestop
fi
ps ax |grep mosq > /dev/null
if [ "0" == "$?" ]; then
	service mosquitto stop
fi
ps ax |grep gsad > /dev/null
if [ "0" == "$?" ]; then
	service gsad stop
	sleep 1
	pkill -9 gsad
fi
set -e

sysrc mosquitto_enable=YES
sysrc gsad_enable=YES
sysrc gvmd_enable=YES
sysrc ospd_openvas_enable=YES
sysrc notus_scanner_enable=YES
# Populate database
echo Populating database.
su -m gvm -c "gvmd -m"

# Set up certificates via gvm
# su -m gvm -c "gvm-manage-certs -a

# synchronize feeds
echo Synchronizing feeds.
mkdir -p /var/lib/openvas/plugins/notus/products
chown -R gvm /var/lib/openvas/

su -m gvm -c "cd /tmp && greenbone-nvt-sync"
su -m gvm -c "greenbone-feed-sync --type GVMD_DATA"
su -m gvm -c "greenbone-feed-sync --type SCAP"
su -m gvm -c "greenbone-feed-sync --type CERT"

# Create admin user
set +e
ADMIN_UUID=$(su -m gvm -c "gvmd --get-users -v" | grep admin|awk '{print $2}')
set -e
if [ "" != "${ADMIN_UUID}" ]; then
	echo admin user already exists. Not creating.
else
	echo Creating GVM admin user : ${USER_ADMIN}
	su -m gvm -c "gvmd --create-user=admin --password=${USER_ADMIN}"
fi
ADMIN_UUID=$(su -m gvm -c "gvmd --get-users -v" | grep admin|awk '{print $2}')
su -m gvm -c "gvmd --modify-setting 78eceaec-3385-11ea-b237-28d24461215b --value ${ADMIN_UUID}"

# patch gvmd rc script
set +e
cat /usr/local/etc/rc.d/gvmd | grep PATH > /dev/null
if [ "0" != "$?" ]; then
	sed -i '' '/gvmd.pid/a\
export PATH=/usr/local/bin:/usr/local/sbin:$PATH
' /usr/local/etc/rc.d/gvmd
fi
cat /usr/local/etc/rc.d/ospd_openvas | grep OPENVAS_GNUPG_HOME > /dev/null
if [ "0" != "$?" ]; then
	sed -i '' '/ospd\_openvas\_pidfile}/a\
export OPENVAS_GNUPG_HOME=/var/lib/gvm/gvmd/gnupg
' /usr/local/etc/rc.d/ospd_openvas
sed -i '' '/ospd\_openvas\_pidfile}/a\
export GNUPGHOME=/var/lib/gvm/gvmd/gnupg
' /usr/local/etc/rc.d/ospd_openvas
fi
set -e

# creating missing directories
mkdir -p /usr/local/share/gvm/gsad
chown gvm:gvm /usr/local/share/gvm/gsad
mkdir -p /usr/local/share/gvm/gsad/web
chown gvm:gvm /usr/local/share/gvm/gsad/web
pkg install -y gsa

# start services
service mosquitto start
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

