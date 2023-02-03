#!/bin/bash

# Create secrets
sudo mkdir -p /etc/secrets/
sudo chmod -R 600 /etc/secrets/

# Prompt for MySQL root password
read -s -p "Enter MySQL root password: "
sudo echo "$REPLY" > /etc/secrets/mysql_db
unset REPLY
password_file1=/etc/secrets/mysql_db

# Prompt for Zabbix database password
read -s -p "Enter Zabbix database password: "
sudo echo "$REPLY" > /etc/secrets/zabbix_db
unset REPLY
password_file2=/etc/secrets/zabbix_db

# Update the package repository
sudo apt-get update -y

# Install the mysql server
sudo apt-get install -y mysql-server

# Start the MySQL service
sudo service mysql start

# Set mysql root password
echo "Setting MySQL root password..."
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$(cat $password_file1)'; FLUSH PRIVILEGES;"
echo "MySQL root password set successfully!"

# Install Zabbix repository
wget https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.0-4%2Bubuntu22.04_all.deb
sudo dpkg -i zabbix-release_6.0-4+ubuntu22.04_all.deb
sudo apt-get update -y

# Install Zabbix server, frontend, agent
sudo apt-get install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent
echo "Zabbix frontend installed..."

# Create initial database
echo "Configuring database..."
sudo mysql -uroot -p$(cat $password_file1) -e "create database zabbix character set utf8mb4 collate utf8mb4_bin;"
sudo mysql -uroot -p$(cat $password_file1) -e "create user zabbix@localhost identified by '$(cat $password_file2)';"
sudo mysql -uroot -p$(cat $password_file1) -e "grant all privileges on zabbix.* to zabbix@localhost;"
sudo mysql -uroot -p$(cat $password_file1) -e "set global log_bin_trust_function_creators = 1;"

# Import database
echo "Extracting database, this could take a while..."
sudo zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -D zabbix --default-character-set=utf8mb4 -uzabbix -p$(cat $password_file2)
sudo mysql -uroot -p$(cat $password_file1) -e "set global log_bin_trust_function_creators = 0;"

# Configure the Zabbix server to use the database
echo "Configure the Zabbix server to use the database..."
sudo sed -i "s/# DBPassword=.*/DBPassword=$(cat $password_file2)/g" /etc/zabbix/zabbix_server.conf

sudo systemctl restart zabbix-server zabbix-agent apache2
sudo systemctl enable zabbix-server zabbix-agent apache2

# Remove secrets
sudo rm -rf /etc/secrets/

echo "...Install complete..."

# Remove the script
rm -- "$0"
