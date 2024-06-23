#!/bin/bash

source .piler.env
PILER_DOMAIN="${mypilerdomain}"
MAILSERVER_DOMAIN="${mypilermaildomain}"
MARIADB_VERSION="10.8"
SPHINX_VERSION="3.4.1"
GENERATE_CERTIFICATES="NO"

prepSystem () {
    apt install sysstat build-essential libwrap0-dev libpst-dev tnef libytnef0-dev unrtf catdoc libtre-dev tre-agrep poppler-utils libzip-dev unixodbc libpq5 software-properties-common libpoppler-dev openssl libssl-dev python3-mysqldb memcached pwgen telnet

    apt remove --yes snapd multipath-tools
    apt autoremove --yes
}

installMariaDb () {
    curl -LsS -O https://downloads.mariadb.com/MariaDB/mariadb_repo_setup
    bash mariadb_repo_setup --os-type=ubuntu  --os-version=focal --mariadb-server-version=${MARIADB_VERSION}

    ## Ubuntu 22.04 doesn't include OpenSSL 1.1.1. Needs to be downloaded and installed using dpkg to satisfy MariaDB dependencies
    wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.16_amd64.deb
    dpkg -i libssl1.1_1.1.1f-1ubuntu2.16_amd64.deb

    ## Also missing libreadline5. Hacky workaround is to download package from Debian repo and install manually
    wget http://ftp.uk.debian.org/debian/pool/main/r/readline5/libreadline5_5.2+dfsg-3+b13_amd64.deb
    dpkg -i libreadline5_5.2+dfsg-3+b13_amd64.deb

    ## Install MariaDB server, client and developer compatibility libraries
    apt install mariadb-{server,client} libmariadb-dev-compat

    ## Database optimisations for Piler as per FAQ
    cat > /etc/mysql/conf.d/mailpiler.conf <<EOF
innodb_buffer_pool_size=256M
innodb_flush_log_at_trx_commit=1
innodb_log_buffer_size=64M
innodb_log_file_size=16M
query_cache_size=0
query_cache_type=0
query_cache_limit=2M
EOF

    systemctl restart mariadb
}

installPhp () {
    ## Add PHP repo, install PHP7.4 with additional modules
    add-apt-repository --yes ppa:ondrej/php
    apt install php7.4-{fpm,common,ldap,mysql,cli,opcache,phpdbg,gd,memcache,json,readline,zip} -y
}

installNginx () {
    ## Install Nginx
    add-apt-repository --yes ppa:ondrej/nginx-mainline
    apt install nginx -y
    systemctl enable nginx
}

installSphinx () {
    ## Install Sphinx Search
    mkdir -p /root/mailpiler/sphinxsearch/
    cd /root/mailpiler/sphinxsearch/
    wget http://sphinxsearch.com/files/sphinx-3.4.1-efbcc65-linux-amd64.tar.gz
    tar xfz sphinx-*-linux-amd64.tar.gz
    cp -v sphinx-*/bin/* /usr/local/bin/
    rm /etc/cron.d/sphinxsearch
}

installXlhtml () {
    ## Install and comple xlhtml
    mkdir -p /usr/local/src/xlhtml/
    cd /usr/local/src/
    wget https://bitbucket.org/jsuto/piler/downloads/xlhtml-0.5.1-sj-mod.tar.gz
    tar xzf xlhtml-*-sj-mod.tar.gz
    cd xlhtml-*-sj-mod/
    ./configure
    make
    make install
    ldconfig
}

setPermissions () {
    ## Create Piler user and group and set permissions/home directory
    groupadd piler
    useradd -g piler -m -s /bin/bash -d /var/piler piler
    usermod -L piler
    chmod 755 /var/piler
}

downloadAndCompile () {
    ## Download and compile piler
    mkdir -p /usr/local/src/
    cd /usr/local/src
    #wget https://bitbucket.org/jsuto/piler/downloads/piler-1.3.12.tar.gz
    wget https://bitbucket.org/jsuto/piler/downloads/piler-${PILER_VERSION}.tar.gz
    tar xzf piler-*.tar.gz
    cd piler-*/
    ./configure --localstatedir=/var --with-database=mysql --enable-memcached
    make
    make install
    ldconfig
}

postInstallScript () {
    ## Generate Piler's MySQL password 
    PILER_MYSQL_USER_PW="$(pwgen -cnsB 32 1)"
    echo; echo "---"; echo "MYSQL PILER PASSWORD: $PILER_MYSQL_USER_PW"; echo "---"; echo
    echo "Copy this as you'll need it in a second..."

    ## Set mail server address and run postinstall script
    cp util/postinstall.sh util/postinstall.sh.bak
    sed -i "s/   SMARTHOST=.*/   SMARTHOST="\"$MAILSERVER_DOMAIN\""/" util/postinstall.sh
    sed -i 's/   WWWGROUP=.*/   WWWGROUP="www-data"/' util/postinstall.sh
}

pilerServicesConfig () {
    ## Backup config files and modify with appropriate values
    cp /usr/local/etc/piler/piler.conf /usr/local/etc/piler/piler.conf.bak
    cp /usr/local/etc/piler/sphinx.conf /usr/local/etc/piler/sphinx.conf.bak

    sed -i "s/hostid=.*/hostid=${PILER_DOMAIN}/" /usr/local/etc/piler/piler.conf
    sed -i "s/update_counters_to_memcached=.*/update_counters_to_memcached=1/" /usr/local/etc/piler/piler.conf
    sed -i "s/spam_header_line=.*/spam_header_line=X-Spam-Flag: YES/" /usr/local/etc/piler/piler.conf # rspamd in mailcow setup.

    sed -i "s/define('SPHINX_VERSION', .*/define('SPHINX_VERSION', $(echo $SPHINX_VERSION | sed -e 's/\.//g'));/" /usr/local/etc/piler/sphinx.conf
    sed -i "s/define('SPHINX_STRICT_SCHEMA', 0);/define('SPHINX_STRICT_SCHEMA', 1);/" /usr/local/etc/piler/sphinx.conf # required for Sphinx 3.x.x
    cd /etc
    ln -s /usr/local/etc/piler piler
}

startPilerServices () {
    ## Start piler and searchd and enable auto-run
    #/etc/init.d/rc.piler start
    #/etc/init.d/rc.searchd start
    #update-rc.d rc.piler defaults
    #update-rc.d rc.searchd defaults
    systemctl enable piler
    systemctl enable searchd
    systemctl start piler
    systemctl start searchd
}

nginxConfig () {
    ## Copy stock nginx config file and modify with hostname
    cp contrib/webserver/piler-nginx.conf /etc/nginx/sites-enabled/piler
    sed -i "s|PILER_HOST|$PILER_DOMAIN|g" /etc/nginx/sites-enabled/piler
    sed -i "s|/var/run/php/php7.2-fpm.sock|/var/run/php/php7.4-fpm.sock|g" /etc/nginx/sites-enabled/piler

    ## Create function that configures Nginx for use wuth self-signed SSL certificates and redirect from http
    nginxConfigureSsl () {
        mkdir -p /etc/nginx/ssl
        openssl req -x509 -nodes -days 3650 -newkey rsa:4096 -keyout /etc/nginx/ssl/piler.key -out /etc/nginx/ssl/piler.crt -subj "/CN=$PILER_DOMAIN" -addext "subjectAltName=DNS:$PILER_DOMAIN"
        sed -i "/server_name.*/a \\
listen 443 ssl http2;\n\n\
ssl_certificate /etc/nginx/ssl/piler.crt;\n\
ssl_certificate_key /etc/nginx/ssl/piler.key;\n\n\
ssl_session_timeout 1d;\n\
ssl_session_cache shared:SSL:15m;\n\
ssl_session_tickets off;\n\n\
# modern configuration of Mozilla SSL configurator. Tweak to your needs.\n\
ssl_protocols TLSv1.2 TLSv1.3;\n\
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;\n\
ssl_prefer_server_ciphers off;\n\n\
add_header X-Frame-Options SAMEORIGIN;\n\
add_header X-Content-Type-Options nosniff;" /etc/nginx/sites-enabled/piler

        sed -i "/^server {.*/i\
\# HTTP to HTTPS redirect.\n\
server {\n\
        listen 80;\n\
        server_name $PILER_DOMAIN;\n\
        return 301 https://\$host\$request_uri;\n\
}" /etc/nginx/sites-enabled/piler
    }

    ## Configure Nginx if no SSL required
    nginxNoSsl () {

    }

    read -p "Do you want to configure your server for SSL?" yn
    case $yn in
        [Yy]* ) nginxConfigureSsl;;
        [Nn]* ) nginxNoSsl;;
        * ) echo "Please answer yes (Y/y) or no (N/n).";;
    esac

    NGINX_SUCCESS=$(nginx -t 2>&1)
    if [[ $NGINX_SUCCESS =~ .*successful.* ]]; then
        systemctl restart nginx
        echo "Nginx ready";
        else
        echo "Nginx configuration issue";
    fi
}

## Configure Piler Web UI
configurePilerWebUi () {
cp /usr/local/etc/piler/config-site.php /usr/local/etc/piler/config-site.bak.php

sed -i "s|\$config\['SITE_URL'\] = .*|\$config\['SITE_URL'\] = 'https://$PILER_DOMAIN/';|" /usr/local/etc/piler/config-site.php

cat >> /usr/local/etc/piler/config-site.php <<EOF

// CUSTOM
\$config['PROVIDED_BY'] = '$MAILSERVER_DOMAIN';
\$config['SUPPORT_LINK'] = 'https://$MAILSERVER_DOMAIN';
\$config['COMPATIBILITY'] = '';

// fancy features.
\$config['ENABLE_INSTANT_SEARCH'] = 1;
\$config['ENABLE_TABLE_RESIZE'] = 1;

\$config['ENABLE_DELETE'] = 1;
\$config['ENABLE_ON_THE_FLY_VERIFICATION'] = 1;

// general settings.
\$config['TIMEZONE'] = '$SERVER_TIMEZONE';

// authentication
// Enable authentication against an imap server
\$config['ENABLE_IMAP_AUTH'] = 1;
\$config['RESTORE_OVER_IMAP'] = 1;
\$config['IMAP_RESTORE_FOLDER_INBOX'] = 'INBOX';
\$config['IMAP_RESTORE_FOLDER_SENT'] = 'Sent';
\$config['IMAP_HOST'] = '$MAILSERVER_DOMAIN';
\$config['IMAP_PORT'] =  993;
\$config['IMAP_SSL'] = true;

// special settings.
\$config['MEMCACHED_ENABLED'] = 1;
\$config['SPHINX_STRICT_SCHEMA'] = 1; // required for Sphinx 3.3.1, see https://bitbucket.org/jsuto/piler/issues/1085/sphinx-331.
EOF
}

finishedCheck () {
GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
NORMAL=$(tput sgr0)

PROCESSES=( nginx sphinxd piler )
for PROCESS in ${PROCESSES[@]}
do
STATUS=$(systemctl status ${PROCESS} 2>&1 | grep Active | sed -e 's/.*Active:\s//' | sed -e 's/\(.*\)since.*/\1/')
   if [[ $STATUS =~ .*\sactive.* ]]
    then
     STATUS_COLOR=$GREEN
    elif [[ $STATUS =~ .*failed.* ]]; then
        STATUS_COLOR=$RED
    elif [[ $STATUS =~ .*dead.* ]]; then
        STATUS_COLOR=$RED
    elif [[ -z $STATUS ]]; then
        STATUS="No Process Running" && STATUS_COLOR=$NORMAL 
    else
        STATUS_COLOR=$NORMAL
    fi
    echo "$PROCESS:      ${STATUS_COLOR}${STATUS}${NORMAL}"
done

                }

prepSystem
installMariaDb
installPhp
installNginx
installSphinx
installXlhtml
setPermissions
downloadAndCompile
postInstallScript
pilerServicesConfig
startPilerServices
nginxConfig
configurePilerWebUi
finishedCheck

echo "all done";
