#!/bin/bash

## ENVIRONMENT VARIABLES
SOURCEDIR=/usr/local/src

## MODULE SELECTION
INSTALL_PCRE=yes
INSTALL_ZLIB=yes
INSTALL_HEADERS_MORE=no
INSTALL_PAGESPEED=yes
INSTALL_OPENSSL=yes

## VERSIONS
#NGINX_VERSION=1.21.3
NGINX_BRANCH=stable
PCRE_VERSION=8.45
ZLIB_VERSION=1.2.12
#HEADERS_MORE_VERSION=0.33
#PAGESPEED_VERSION=1.13.35.2
PAGESPEED_BRANCH=latest-stable
OPENSSL_VERSION=1.1.1q

## REPOS
#MAXMIND_REPO="ppa:maxmind/ppa"
NGINX_REPO="ppa:ondrej/nginx-mainline"
add-apt-repository $NGINX_REPO

## DEPENDENCIES
PAGESPEED_DEPENDENCIES="build-essential"    
NGINX_DEPENDENCIES="\
checkinstall \
libpcre3 \
libpcre3-dev \
zlib1g-dbg \
zlib1g-dev \
curl gnupg2 \
ca-certificates \
lsb-release \
build-essential \
unzip \
uuid-dev \
software-properties-common \
gnupg2 \
dpkg-dev \
"

## UPDATE AND UPGRADE
apt update
apt upgrade -y

## PAGESPEED

cd $SOURCEDIR
if [ $INSTALL_PAGESPEED = "yes" ]; then
    apt install $PAGESPEED_DEPENDENCIES -y
    if [ $PAGESPEED_BRANCH != "latest-stable" ]; then
        wget https://github.com/apache/incubator-pagespeed-ngx/archive/refs/tags/v${PAGESPEED_VERSION}-${PAGESPEED_BRANCH}.zip
        unzip v${PAGESPEED_VERSION}-${PAGESPEED_BRANCH}.zip
        PAGESPEED_DIR="incubator-pagespeed-ngx-${PAGESPEED_VERSION}-${PAGESPEED_BRANCH}"
        psol_url="https://dl.google.com/dl/page-speed/psol/${PAGESPEED_VERSION}.tar.gz"
        PAGESPEED_RELEASE=$PAGESPEED_VERSION-$PAGESPEED_BRANCH
        echo "Pagespeed ${PAGESPEED_RELEASE} Downloaded"
    else
        wget https://github.com/apache/incubator-pagespeed-ngx/archive/refs/tags/latest-stable.zip
        unzip latest-stable.zip
        PAGESPEED_DIR=incubator-pagespeed-ngx-latest-stable
        PAGESPEED_RELEASE=latest-stable
        echo "Pagespeed ${PAGESPEED_RELEASE} Downloaded"
    fi
    cd /usr/local/src/$PAGESPEED_DIR
    PSOL_BINARY_URL=$(cat PSOL_BINARY_URL)
    [ -e scripts/format_binary_url.sh ] && psol_url=$(scripts/format_binary_url.sh PSOL_BINARY_URL)
    wget -O- ${psol_url} | tar -xz
fi

## PCRE
wget https://downloads.sourceforge.net/project/pcre/pcre/${PCRE_VERSION}/pcre-${PCRE_VERSION}.tar.bz2
tar -xvf pcre-${PCRE_VERSION}.tar.bz2

## ZLIB
wget http://zlib.net/zlib-${ZLIB_VERSION}.tar.gz
tar -xvf zlib-${ZLIB_VERSION}.tar.gz

## OpenSSL
wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz
tar -xvf openssl-${OPENSSL_VERSION}.tar.gz

## Nginx
add-apt-repository $NGINX_REPO -y
apt update
apt dist-upgrade -y
apt install $NGINX_DEPENDENCIES -y
apt install nginx-core nginx-common nginx nginx-full -y
NGINX_APT_LIST=$(ls /etc/apt/sources.list.d/ | grep ondrej)
sed -i 's/# deb/deb/g' $NGINX_APT_LIST
apt update
mkdir -p $SOURCEDIR/nginx
apt source nginx
NGINX_VERSION=$(nginx -v 2>&1 | sed -En 's/^nginx version: nginx\/(.*)$/\1/p')
cd nginx-$NGINX_VERSION
apt build-dep nginx
./configure \
--prefix=/etc/nginx \
--sbin-path=/usr/sbin/nginx \
--modules-path=/usr/lib/nginx/modules \
--conf-path=/etc/nginx/nginx.conf \
--error-log-path=/var/log/nginx/error.log \
--http-log-path=/var/log/nginx/access.log \
--pid-path=/var/run/nginx.pid \
--lock-path=/var/run/nginx.lock \
--http-client-body-temp-path=/var/cache/nginx/client_temp \
--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
--user=www-data \
--group=www-data \
--with-compat \
--with-file-aio \
--with-threads \
--with-http_addition_module \
--with-http_auth_request_module \
--with-http_dav_module \
--with-http_flv_module \
--with-http_gunzip_module \
--with-http_gzip_static_module \
--with-http_mp4_module \
--with-http_random_index_module \
--with-http_realip_module \
--with-http_secure_link_module \
--with-http_slice_module \
--with-http_ssl_module \
--with-http_stub_status_module \
--with-http_sub_module \
--with-http_v2_module \
--with-mail \
--with-mail_ssl_module \
--with-stream \
--with-stream_realip_module \
--with-stream_ssl_module \
--with-stream_ssl_preread_module \
--with-pcre \ #=../pcre-${PCRE_VERSION}
--with-zlib \ #=../zlib-${ZLIB_VERSION}
--with-cc-opt='-g -O2 -fdebug-prefix-map=/data/builder/debuild/nginx-${NGINX_VERSION}/debian/debuild-base/nginx-${NGINX_VERSION}=. -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC' \
--with-ld-opt='-Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie'
make
make install
mkdir -p /var/cache/nginx/client_temp
systemctl stop apache2
systemctl disable apache2
mkdir /var/log/nginx
mkdir /var/cache/nginx && chown www-data:www-data /var/cache/nginx
mkdir /etc/nginx/sites-available && mkdir /etc/nginx/sites-enabled

# #cat <<EOT >> /lib/systemd/system/nginx.service
# #[Unit]
# Description=The NGINX HTTP and reverse proxy server
# After=syslog.target network-online.target remote-fs.target nss-lookup.target
# Wants=network-online.target

# [Service]
# Type=forking
# PIDFile=/run/nginx.pid
# ExecStartPre=/usr/sbin/nginx -t
# ExecStart=/usr/sbin/nginx
# ExecReload=/usr/sbin/nginx -s reload
# ExecStop=/bin/kill -s QUIT $MAINPID
# PrivateTmp=true

# [Install]
# WantedBy=multi-user.target
# EOT
