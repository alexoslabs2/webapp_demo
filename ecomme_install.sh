#Ecomme - Simple PHP Application
#!/bin/bash

DB_PASSWORD="Secret"
APACHE_LOG_DIR=/var/log/apache2/
log=~/ecomme.log

#Check sudo
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

clear

echo -ne Installing Dependencies..
apt-get update > $log
apt-get install -y apache2 mariadb-server php libapache2-mod-php php-mysql git-core telnet >> $log
systemctl enable apache2
systemctl enable mariadb
systemctl start apache2
systemctl start mariadb
sleep 1
echo Done

echo -ne Hardening MariaDB...
mysql_secure_installation << EOF
n
$DB_PASSWORD
$DB_PASSWORD
y
y
y
y
y
EOF
sleep 1
echo Done
clear

echo -ne Creating database ecomme...
mysql -u root -p$DB_PASSWORD -e "CREATE DATABASE ecomme;"
mysql -u root -p$DB_PASSWORD -e "GRANT ALL ON ecomme.* TO 'ecomme_user'@'%' IDENTIFIED BY 'password';FLUSH PRIVILEGES;"
sleep 1
echo Done

echo -ne Hardening Apache2...
cd /etc/apache2
cp apache2.conf apache2.bak
echo 'KeepAlive Off' >> apache2.conf
echo 'Options -Indexes -FollowSymlinks' >> apache2.conf
echo 'ServerSignature Off' >> apache2.conf
echo 'ServerTokens Prod' >> apache2.conf
echo 'TraceEnable Off' >> apache2.conf
echo '<IfModule mod_headers.c>' >> apache2.conf
echo 'Header set X-XSS-Protection "1; mode=block"' >> apache2.conf
echo '</IfModule>' >> apache2.conf
echo '<IfModule mod_headers.c>' >> apache2.conf
echo 'Header edit Set-Cookie ^(.*)$ $1;HttpOnly;Secure' >> apache2.conf
echo '</IfModule>' >> apache2.conf
sed -e 's/expose_php = On/expose_php = Off/' /etc/php/7.4/apache2/
a2dissite 000-default
sleep 1
echo Done

echo -ne Installing Ecomme Application...
cd /var/www/html
git clone https://github.com/jenil/simple-ecomme.git >> $log
chown -R www-data. simple-ecomme
cd simple-ecomme
echo > config.php
tee config.php << EOF
<?php
ini_set('display_errors',1);
error_reporting(-1);
define('DB_HOST', 'localhost');
define('DB_USER', 'ecomme');
define('DB_PASSWORD', 'ecomme_user');
define('DB_DATABASE', 'password');
?>
EOF
mysql -u root -p$DB_PASSWORD ecomme < dump.sql
cd /etc/apache2/sites-available
tee ecomme.conf << EOF
<VirtualHost *:80>
DocumentRoot /var/www/html/simple-ecomme
ErrorLog $APACHE_LOG_DIR/error.log
CustomLog $APACHE_LOG_DIR/access.log combined
</VirtualHost>
EOF
a2ensite ecomme >> $log
systemctl restart apache2 >> $log
sleep 1
echo Done
