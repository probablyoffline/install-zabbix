#!/bin/bash

# Prompt for zabbix FQDN
read -p "Enter Zabbix server FQDN: " zabbix_fqdn
host_ip=$(hostname -I)
host_string="$host_ip $zabbix_fqdn"

# Get the hostname from FQDN
server_hostname="${zabbix_fqdn%%.*}"

#Create dir for keys
sudo mkdir /etc/apache2/ssl
sudo mkdir /etc/apache2/ssl/private

# Generate cert, Default country code of US.
sudo openssl req -x509 -subj "/C=US" -nodes -days 365 -newkey rsa:2048 -keyout /etc/apache2/ssl/private/apache-selfsigned.key -out /etc/apache2/ssl/apache-selfsigned.crt

# Check if the host IP and FQDN already exist on the same line in the file
if ! grep -Eq "$host_ip.*$zabbix_fqdn" /etc/hosts; then
  # Using sed to add the variable to the end of the file
  sed -i '$ a\'"$host_string"'\' /etc/hosts
else
  echo "FQDN entry already exists in /etc/hosts, skipping"
fi

# backup the original host file
cp /etc/hosts /etc/hosts.bak

# use grep to find the line that contains 127.0.0.1 or 127.0.1.1 and $server_hostname
if grep -qE "^(127.0.0.1|127.0.1.1).*$server_hostname" /etc/hosts; then
  # if it does, check if the line is already commented out
  if grep -qE "^#\s*(127.0.0.1|127.0.1.1).*$server_hostname" /etc/hosts; thenn
    # if it is, leave the file unchanged
    cp /etc/hosts /etc/hosts.temp
  else
    # if it's not, comment it out by adding a # symbol at the beginning of the line
    sed -E "s/^(\(127.0.0.1\)|\(127.0.1.1\)).*$server_hostname.*$/# \1 \2 \3/" /etc/hosts > /etc/hosts.temp
  fi
else
  # if it doesn't, leave the file unchanged
  cp /etc/hosts /etc/hosts.temp
fi

# replace the original file with the modified version
mv /etc/hosts.temp /etc/hosts

# Update SSLCertificate values, adding 2 tabs before the new value to match spacing
FILE="/etc/apache2/sites-available/default-ssl.conf"
sed -i 's|^\s*SSLCertificateFile.*|\t\tSSLCertificateFile /etc/apache2/ssl/apache-selfsigned.crt|' $FILE
sed -i 's|^\s*SSLCertificateKeyFile.*|\t\tSSLCertificateKeyFile /etc/apache2/ssl/private/apache-selfsigned.key|' $FILE
sed -i 's|^\s*ServerName.*|\t\tServerName $zabbix_fqdn|' $FILE
sed -i 's|^\s*ServerAlias.*|\t\tServerAlias $zabbix_fqdn|' $FILE
echo "Updated /etc/apache2/sites-available/default-ssl.conf"

#Check if config is set correctly
sudo apache2ctl configtest
echo "Apache config looks fine."

#Enable SSL for default-ssl
sudo a2ensite default-ssl

#Enable SSL module
sudo a2enmod ssl
sudo systemctl restart apache2 

# Add apache https rewrite
file2="/etc/apache2/sites-available/000-default.conf"

if [ -f "$file2" ]; then
  # Check if the additions already exist
  if grep -q "RewriteEngine On" "$file2" && grep -q "RewriteCond %{HTTPS} off" "$file2" && grep -q "RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]" "$file2"; then
    echo "Additions already exist, exiting."
    exit 0
  fi

  # Add the additions
  sed -i '/<VirtualHost \*:80>/a \\tRewriteEngine On\n\tRewriteCond %{HTTPS} off\n\tRewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]' "$file2"
  echo "Additions added successfully."
else
  echo "File not found, exiting."
  exit 1
fi

# Enable apache rewrite module and restart
sudo a2enmod rewrite
sudo systemctl restart apache2
echo "Restarted apache"

# Change the default root web path
sed -i 's/\/var\/www\/html/\/usr\/share\/zabbix/g' /etc/apache2/sites-available/000-default.conf
sed -i 's/\/var\/www\/html/\/usr\/share\/zabbix/g' /etc/apache2/sites-enabled/default-ssl.conf
sudo sed -i 's/^Alias \/zabbix/#&/' /etc/apache2/conf-available/zabbix.conf

# Restart apache and done
sudo systemctl restart apache2
echo "HTTPS config complete."

# Remove the script
rm -- "$0"
