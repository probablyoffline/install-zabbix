#!/bin/bash

# prompt for MySQL root password
read -s -p "Enter MySQL root password: " root_password
echo

# Prompt for the zabbix database password
read -s -p "Enter the Zabbix database password: " zabbix_password

# Update the package repository
sudo apt-get update -y

# Install the mysql server
sudo apt-get install -y mysql-server

# Start the MySQL service
sudo service mysql start

# set root password
echo "Setting MySQL root password..."
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$root_password'; FLUSH PRIVILEGES;"
echo "MySQL root password set successfully!"

# Install Zabbix repository
wget https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.0-4%2Bubuntu22.04_all.deb
sudo dpkg -i zabbix-release_6.0-4+ubuntu22.04_all.deb
sudo apt-get update -y

# Install Zabbix server, frontend, agent
sudo apt-get install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent
echo "Zabbix frontend installed..."

# Create initial database
sudo mysql -uroot -p$root_password -e "create database zabbix character set utf8mb4 collate utf8mb4_bin;"
sudo mysql -uroot -p$root_password -e "create user zabbix@localhost identified by '$zabbix_password';"
sudo mysql -uroot -p$root_password -e "grant all privileges on zabbix.* to zabbix@localhost;"
sudo mysql -uroot -p$root_password -e "set global log_bin_trust_function_creators = 1;"
sudo history -c
echo "Password cleared from history"

echo "Extracting database, this could take a while..."
sudo zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -D zabbix --default-character-set=utf8mb4 -uzabbix -p$zabbix_password
sudo mysql -uroot -p$root_password -e "set global log_bin_trust_function_creators = 0;"
sudo history -c
echo "Password cleared from history"

# Configure the Zabbix server to use the database
sudo sed -i "s/# DBPassword=.*/DBPassword=$zabbix_password/g" /etc/zabbix/zabbix_server.conf

sudo systemctl restart zabbix-server zabbix-agent apache2
sudo systemctl enable zabbix-server zabbix-agent apache2

# Remove the script
sudo history -c
history -c
rm -- "$0"
