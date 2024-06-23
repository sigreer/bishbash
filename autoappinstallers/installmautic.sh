#!/bin/bash
apt update
apt install curl composer
apt install composer nginx php php-{xml,zip,mbstring,json,phar,curl,bcmath,imap,mysql,intl}
sed -i '/date.timezone/c\date.timezone=Europe\/London' /etc/php/7.4/cli/php.ini
sed -i '/date.timezone/c\date.timezone=Europe\/London' /etc/php/7.4/fpm/php.ini
sed -i '/memory_limit/c\memory_limit = 512M' /etc/php/7.4/fpm/php.ini
