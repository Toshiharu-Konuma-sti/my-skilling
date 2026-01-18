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

ARTF_VERSION="7.125.11"
XRAY_VERSION="3.131.27"
XRAY_ARCHIVE="jfrog-xray.tar.gz"
RABT_VERSION="v4.2.2"
RABT_PACKAGE="rabbitmq-server_4.2.2-1_all.deb"


echo "\n### START: Install PostgreSQL #######################################"

sudo apt update
sudo apt install -y postgresql postgresql-contrib

echo "Enable and Start Services..."
sudo systemctl enable postgresql
sudo systemctl start postgresql


cat << EOS

######################################################################
# Installing Artifactory
# - https://jfrog.com/help/r/jfrog-installation-setup-documentation/install-artifactory-on-debian
# - https://jfrog.com/help/r/jfrog-installation-setup-documentation/create-the-artifactory-postgresql-database
######################################################################
EOS

echo "\n### START: 0. Setup Database Users and Schemas ####################"
sudo -u postgres psql <<EOF
-- Artifactory Setup
CREATE USER artifactory WITH PASSWORD 'password';
CREATE DATABASE artifactory WITH OWNER=artifactory ENCODING='UTF8';
GRANT ALL PRIVILEGES ON DATABASE artifactory TO artifactory;
EOF

echo "\n### START: 1. Set JFROG_HOME Variable ###############################"
export JFROG_HOME=/opt/jfrog

echo "\n### START: 2. Configure JFrog APT Repository and Install Artifactory ###"

echo "\n### START: 2-1. Determine Your Debian Distribution: #################"
DISTRIBUTION=$(lsb_release -c | awk '{print $2}')

echo "\n### START: 2-2. Add JFrog APT Repository: ###########################"
echo "deb https://releases.jfrog.io/artifactory/artifactory-pro-debs ${DISTRIBUTION} main" | sudo tee -a /etc/apt/sources.list

echo "\n### START: 2-3. Add JFrog Public Key: ###############################"
wget -qO - https://releases.jfrog.io/artifactory/api/v2/repositories/artifactory-pro-debs/keyPairs/primary/public | sudo apt-key add -

echo "\n### START: 2-4. Update APT Cache and Install Artifactory: ###########"
sudo apt-get update
sudo apt-get install -y net-tools
sudo apt-get install -y jfrog-artifactory-pro=${ARTF_VERSION}

echo "\n### START: 4. Set up Artifactory Database ###########################"

echo "\n### START: 4-1. Configure Artifactory to Use PostgreSQL #############"
# - https://jfrog.com/help/r/jfrog-installation-setup-documentation/configure-artifactory-to-use-postgresql-single-node
ARTF_SYS_FILE="$JFROG_HOME/artifactory/var/etc/system.yaml"
sudo cp ${ARTF_SYS_FILE} ${ARTF_SYS_FILE}.bak
sudo sed -i '/^[[:space:]]*database:/a \
        allowNonPostgresql: false\
        type: postgresql\
        driver: org.postgresql.Driver\
        url: "jdbc:postgresql://localhost:5432/artifactory"\
        username: "artifactory"\
        password: "password"' "${ARTF_SYS_FILE}"

echo "\n### START: 6. Start Artifactory #####################################"
echo "\tTo check the startup status:"
echo "$ sudo tail -f /var/opt/jfrog/artifactory/log/artifactory-service.log"
sudo systemctl enable artifactory.service
sudo systemctl start artifactory.service


cat << EOS

######################################################################
# Installing Xray
# - https://jfrog.com/help/r/jfrog-installation-setup-documentation/xray-single-node-manual-debian-installation
# - https://jfrog.com/help/r/jfrog-installation-setup-documentation/create-the-xray-postgresql-database
######################################################################
EOS

sudo apt install -y socat libsctp1 libncurses6

echo "\n### START: 0. Setup Database Users and Schemas ####################"
sudo -u postgres psql <<EOF
-- Xray Setup (Requires pgcrypto extension)
CREATE USER xray WITH PASSWORD 'password';
CREATE DATABASE xraydb WITH OWNER=xray ENCODING='UTF8';
GRANT ALL PRIVILEGES ON DATABASE xraydb TO xray;
-- Enable pgcrypto for Xray
\c xraydb
CREATE EXTENSION IF NOT EXISTS pgcrypto;
EOF

echo "\n### START: 2′. Install Xray #########################################"

echo "\n### START: 2′-1. Download Xray ${XRAY_VERSION} Archive ##############"

if [ ! -f "${XRAY_ARCHIVE}" ]; then
	wget -O ${XRAY_ARCHIVE} "https://releases.jfrog.io/artifactory/jfrog-xray/xray-deb/${XRAY_VERSION}/jfrog-xray-${XRAY_VERSION}-deb.tar.gz"
else
	echo "Skip download: ${XRAY_ARCHIVE} already exists."
fi

echo "\n### START: 2′-2. Extracting Archive #################################"
rm -rf xray_installer
mkdir -p xray_installer
tar -xzf ${XRAY_ARCHIVE} -C xray_installer --strip-components=1

echo "\n### START: 2′-3. Installing Bundled Dependencies ####################"

echo "\n### START: 2′-3-1. Erlang ###########################################"
ERLANG_DEB=$(find xray_installer/third-party/rabbitmq4 -name "*~ubuntu~${DISTRIBUTION}_amd64.deb" | head -n 1)
sudo dpkg -i "$ERLANG_DEB"

#	echo "\n### START: 2′-3-2. RabbitMQ Server ##################################"
#	if [ ! -f "${RABT_PACKAGE}" ]; then
#		wget -O ${RABT_PACKAGE}  https://github.com/rabbitmq/rabbitmq-server/releases/download/${RABT_VERSION}/${RABT_PACKAGE}
#	else
#		echo "Skip download: ${RABT_PACKAGE} already exists."
#	fi
#	sudo dpkg -i ${RABT_PACKAGE}

echo "\n### START: 2′-3-3. YQ (Binary copy) #################################"
sudo cp xray_installer/third-party/yq/yq /usr/local/bin/yq
sudo chmod +x /usr/local/bin/yq

echo "\n### START: 2′-4. Install Xray #######################################"
sudo dpkg -i xray_installer/xray/xray.deb

echo "\n### START: 2′-5. Fixing dependencies  ###############################"
sudo apt-get -f install -y
sudo apt autoremove -y

# Clean up
rm -rf xray_installer


echo "\n### START: 4-2. Configure Xray to Use PostgreSQL #############"
XRAY_SYS_FILE="$JFROG_HOME/xray/var/etc/system.yaml"
sudo cp ${XRAY_SYS_FILE} ${XRAY_SYS_FILE}.bak
sudo sed -i '/^[[:space:]]*database:/a \
    type: postgres\
    driver: postgres\
    url: "postgres://localhost:5432/xraydb?sslmode=disable"\
    username: "xray"\
    password: "password"' "${XRAY_SYS_FILE}"

sudo sed -i '/^[[:space:]]*rabbitMq:/a \
    url: "amqp://localhost:5672/"\
    username: "guest"\
    password: "guest"' "${XRAY_SYS_FILE}"

sudo sed -i 's|#jfrogUrl:|jfrogUrl: "http://localhost:8082"|g' "${XRAY_SYS_FILE}"


echo "\n### START: Synchronize Security Keys from Artifactory to Xray #######"
ART_SEC_DIR=/opt/jfrog/artifactory/var/etc/security
XRAY_SEC_DIR=/opt/jfrog/xray/var/etc/security
echo "Waiting for Artifactory to generate security keys..."
RETRIES=0
while ! sudo test -f "${ART_SEC_DIR}/join.key" || ! sudo test -f "${ART_SEC_DIR}/master.key"; do
    if [ ${RETRIES} -ge 24 ]; then
        echo "Error: Timed out waiting for Artifactory keys."
        echo "Debug info:"
        sudo ls -la ${ART_SEC_DIR}
        exit 1
    fi
    sleep 5
    RETRIES=$((RETRIES+1))
    echo "Waiting... ($((RETRIES*5))s)"
done

echo "Keys detected! Starting synchronization..."

sudo mkdir -p ${XRAY_SEC_DIR}
sudo cp -f ${ART_SEC_DIR}/join.key ${XRAY_SEC_DIR}/join.key
sudo cp -f ${ART_SEC_DIR}/master.key ${XRAY_SEC_DIR}/master.key
sudo chown xray:xray $XRAY_SEC_DIR/join.key
sudo chown xray:xray $XRAY_SEC_DIR/master.key
sudo chmod 640 $XRAY_SEC_DIR/join.key
sudo chmod 640 $XRAY_SEC_DIR/master.key


echo "\n### START: 6-1. Start Xray ##########################################"
echo "$ sudo tail -f /var/opt/jfrog/xray/log/xray-server-service.log"
sudo systemctl enable xray.service
sudo systemctl start xray.service


echo "\n### START: 10. Access Artifactory UI ################################"
cat << EOS
- http://localhost:8082/
- initial accout:
  - user: admin
  - pass: password
EOS


# memo:
# - xary binary:
#   - https://releases.jfrog.io/artifactory/jfrog-xray/xray-deb/3.131.31/jfrog-xray-3.131.31-deb.tar.g
#


finish_banner $S_TIME
