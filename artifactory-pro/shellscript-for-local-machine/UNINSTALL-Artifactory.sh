#!/bin/sh

# {{{ start_banner()
start_banner()
{
	echo "############################################################"
	echo "# START SCRIPT"
	echo "############################################################"
}
# }}}

# {{{ finish_banner()
# $1: time to start this script
finish_banner()
{
	S_TIME=$1
	E_TIME=$(date +%s)
	DURATION=$((E_TIME - S_TIME))
	echo "############################################################"
	echo "# FINISH SCRIPT ($DURATION seconds)"
	echo "############################################################"
}
# }}}

S_TIME=$(date +%s)

start_banner

echo "\n### START: Stopping Services ########################################"

sudo systemctl stop xray.service
sudo systemctl stop artifactory.service
sudo systemctl stop rabbitmq-server
sudo systemctl stop postgresql
sudo systemctl disable xray.service
sudo systemctl disable artifactory.service
sudo systemctl disable rabbitmq-server
sudo systemctl disable postgresql

echo "\n### START: Removing Packages ########################################"

sudo apt-get purge -y jfrog-xray
sudo apt-get purge -y jfrog-artifactory-pro jfrog-artifactory-oss jfrog-artifactory-cpp-ce
sudo apt-get purge -y rabbitmq-server
sudo apt-get purge -y esl-erlang
sudo apt-get purge -y postgresql postgresql-*
sudo apt-get autoremove -y

echo "\n### START: Cleaning up Directories and Files ########################"

echo "Removing JFrog directories..."
sudo rm -rf /opt/jfrog
sudo rm -rf /var/opt/jfrog
sudo rm -rf /etc/opt/jfrog

echo "Removing RabbitMQ Data..."
sudo rm -rf /var/lib/rabbitmq
sudo rm -rf /etc/rabbitmq
sudo rm -rf /var/log/rabbitmq

echo "Removing PostgreSQL data directories..."
sudo rm -rf /var/lib/postgresql
sudo rm -rf /etc/postgresql
sudo rm -rf /var/log/postgresql

echo "Removing manually installed binaries (yq)..."
sudo rm -f /usr/local/bin/yq

echo "\n### START: Removing Users and Groups ################################"
for MY_USER in artifactory xray rabbitmq postgres; do
	sudo userdel -f ${MY_USER}
	sudo groupdel ${MY_USER}
done

echo "\n### START: Reverting APT Configuration ##############################"

if grep -q "jfrog.io" /etc/apt/sources.list; then
	echo "Removing JFrog repository from /etc/apt/sources.list..."
	sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak_before_uninstall
	sudo sed -i '/jfrog\.io/d' /etc/apt/sources.list
fi

JFROG_KEY_ID=$(sudo apt-key list 2>/dev/null | grep -B 1 "JFrog" | head -n 1 | tr -d ' ')
if [ -n "${JFROG_KEY_ID}" ]; then
    echo "Removing JFrog GPG Key: ${JFROG_KEY_ID}"
    sudo apt-key del "${JFROG_KEY_ID}"
fi

echo "\n### START: Updating APT Cache #######################################"
sudo apt-get update

finish_banner $S_TIME
