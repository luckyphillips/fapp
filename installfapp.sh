#!/bin/bash
#Install Apache, PHP, Postresql on Freebsd v12.

pkg install apache24
sysrc apache24_enable=YES
pkg install -y postgresql11-server
sysrc postgresql_enable=YES
/usr/local/etc/rc.d/postgresql initdb
# /usr/local/bin/pg_ctl -D /var/db/postgres/data11 -l logfile start
/usr/local/etc/rc.d/postgresql start 
pkg install -y php74 php74-gd php74-geos php74-curl php74-mbstring php74-openssl php74-pspell php74-pgsql php74-xml php74-mysqli php74-iconv php74-exif php74-json php74-extensions mod_php74

cat <<EOF >> /usr/local/etc/apache24/httpd.conf
<FilesMatch "\.php\$">
    SetHandler application/x-httpd-php
</FilesMatch>
<FilesMatch "\.phps\$">
    SetHandler application/x-httpd-php-source
</FilesMatch>
EOF
pkg install -y wget gmake pcre libiconv libtool python pcre openssl

cd /usr/local/etc/apache24/extra
echo "AddType application/x-httpd-php .php" >> /usr/local/etc/apache24/httpd.conf

mv httpd-ssl.conf httpd-ssl.conf.bak
mkdir /usr/local/etc/apache24/ssl

echo ""
echo "Now add your domain name"
echo "This will be added to your ssl as well."
echo "You will need to have your crt, key and bundle.crt files ready"
echo "You can get them for free from https://zerossl.com/"
echo "It's VERY easy to setup"
echo "Put them into the /usr/local/etc/apache24/ssl directory"
echo "Once you have done that, press enter on here to continue"
read ADDEDSSL
echo ""
echo "Add your domain name that will be added to your apache"
echo "Do NOT add the www ... Just the domain. i.e. mydomain.com"
echo ""
read MYDOMAINNAME
echo "Enter Path for your domain name directory"
read MYDOMAINNAMEPATH
echo "Enter the admin email address for the domain"
read MYDOMAINNAMEEMAIL

cat <<EOF > httpd-ssl.conf
Listen 443
SSLCipherSuite HIGH:MEDIUM:!MD5:!RC4:!3DES
SSLProxyCipherSuite HIGH:MEDIUM:!MD5:!RC4:!3DES
SSLHonorCipherOrder on 
SSLProtocol all -SSLv3
SSLProxyProtocol all -SSLv3
SSLPassPhraseDialog  builtin
SSLSessionCache        "shmcb:/var/run/ssl_scache(512000)"
SSLSessionCacheTimeout  300
<VirtualHost _default_:443>
    DocumentRoot "$MYDOMAINNAMEPATH"
    ServerName $MYDOMAINNAME:443
    ServerAlias www.$MYDOMAINNAME:443
    ServerAdmin $MYDOMAINNAMEEMAIL
    ErrorLog "/var/log/$MYDOMAINNAME-ssl-error.log"
    TransferLog "/var/log/$MYDOMAINNAME-ssl-access.log"
    SSLEngine on
    SSLCertificateFile "/usr/local/etc/apache24/ssl/certificate.crt"
    SSLCertificateKeyFile "/usr/local/etc/apache24/ssl/private.key"
    SSLCertificateChainFile "/usr/local/etc/apache24/ssl/ca_bundle.crt"
    <FilesMatch "\.(cgi|shtml|phtml|php)\$">
        SSLOptions +StdEnvVars
    </FilesMatch>
    <Directory "/usr/local/www/apache24/cgi-bin">
        SSLOptions +StdEnvVars
    </Directory>
    <Directory $MYDOMAINNAMEPATH>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>      
    BrowserMatch "MSIE [2-5]" \
            nokeepalive ssl-unclean-shutdown \
            downgrade-1.0 force-response-1.0
    CustomLog "/var/log/httpd-ssl_request.log" \
            "%t %h %{SSL_PROTOCOL}x %{SSL_CIPHER}x \"%r\" %b"
</VirtualHost>       
EOF

mv httpd-vhosts.conf httpd-vhosts.conf.bak
cat <<EOF >> httpd-vhosts.conf
<VirtualHost *:80>
    ServerAdmin $MYDOMAINNAMEEMAIL
    DocumentRoot "$MYDOMAINNAMEPATH"
    ServerName $MYDOMAINNAME
    ServerAlias www.$MYDOMAINNAME
    ErrorLog "/var/log/$MYDOMAINNAME-error.log"
    CustomLog "/var/log/$MYDOMAINNAME-access.log" common    
    <Directory $MYDOMAINNAMEPATH>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>    
</VirtualHost>
EOF

kldload accf_http
echo 'accf_http_load="YES"' >> /boot/loader.conf

sed -i '' -e 's,#Include etc/apache24/extra/httpd-ssl.conf,Include etc/apache24/extra/httpd-ssl.conf,g' 'httpd.conf'
sed -i '' -e 's,#Include etc/apache24/extra/httpd-default.conf,Include etc/apache24/extra/httpd-default.conf,g' 'httpd.conf'
sed -i '' -e 's,#Include etc/apache24/extra/httpd-vhosts.conf,Include etc/apache24/extra/httpd-vhosts.conf,g' 'httpd.conf'
sed -i '' -e 's,#LoadModule ssl_module libexec/apache24/mod_ssl.so,LoadModule ssl_module libexec/apache24/mod_ssl.so,g' 'httpd.conf'
sed -i '' -e 's,#LoadModule socache_shmcb_module libexec/apache24/mod_socache_shmcb.so,LoadModule socache_shmcb_module libexec/apache24/mod_socache_shmcb.so,g' 'httpd.conf'
sed -i '' -e 's,#LoadModule vhost_alias_module libexec/apache24/mod_vhost_alias.so,LoadModule vhost_alias_module libexec/apache24/mod_vhost_alias.so,g' 'httpd.conf'
sed -i '' -e 's,#LoadModule rewrite_module libexec/apache24/mod_rewrite.so,LoadModule rewrite_module libexec/apache24/mod_rewrite.so,g' 'httpd.conf'
sed -i '' -e "s,ServerAdmin you@example.com,ServerAdmin $MYDOMAINNAMEEMAIL,g" 'httpd.conf'
sed -i '' -e 's,index.html,index.php index.html,g' 'httpd.conf'

if ! [ -d $MYDOMAINNAMEPATH ]
then
mkdir $MYDOMAINNAMEPATH
fi
chmod 775 $MYDOMAINNAMEPATH
if ! [ -f "$MYDOMAINNAMEPATH/index.php" ]
then
echo "It's working" >> $MYDOMAINNAMEPATH/index.php
chmod 775 $MYDOMAINNAMEPATH/index.php
fi
