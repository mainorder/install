#!/bin/bash

set -euxo pipefail

# System dependencies
REQUIRED_PYTHON_VERSION="3.6.1"
THREADS=1

# MainOrder variables
MAINORDER_INSTALL_DIR=${MAINORDER_INSTALL_DIR:-~/mainorder}
MAINORDER_CUSTOMER=${MAINORDER_CUSTOMER:=ask__customer}
MAINORDER_INTERACTIVE=${MAINORDER_INTERACTIVE:=1}
MAINORDER_DATAPLICITY=${MAINORDER_DATAPLICITY:=ug76k9ly}

function confirm() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

function proceed() {
    read -p "Proceed by pressing enter:"
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

function install_python_36(){
	echo "Installing python ${REQUIRED_PYTHON_VERSION}..."
	sudo apt-get install build-essential libc6-dev
	sudo apt-get install libncurses5-dev libncursesw5-dev libreadline6-dev
	sudo apt-get install libdb5.3-dev libgdbm-dev libsqlite3-dev libssl-dev
	sudo apt-get install libbz2-dev libexpat1-dev liblzma-dev zlib1g-dev


	cd $HOME
	wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${REQUIRED_PYTHON_VERSION}.tgz
	tar -zxvf Python-${REQUIRED_PYTHON_VERSION}.tgz
	cd Python-${REQUIRED_PYTHON_VERSION}
	./configure
	make -j${THREADS}
	sudo make install
}

function install_node(){
	curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
	sudo apt-get install -y nodejs
}

# Checking python3 installation
PYTHON_VERSION=$(python3 -V 2>&1 | sed 's/.* \([0-9]\).\([0-9]\).*/\1\2/')

if [[ "$PYTHON_VERSION" -lt "36" ]]
then
	echo "Python >=3.6 not installed. "
	if [[ "$OSTYPE" == "linux-gnu"* && "yes" == $(confirm "Do you want to install python3.6?") ]]
	then
		echo "Installing python 3.6. This may take a while..."
		install_python_36
	fi
	exit
fi

echo "Python >= 3.6 installed. Setting up git project."

# Dependencies
echo "Installing dependencies"

if [[ "$OSTYPE" == "linux-gnu"* ]]
then
	sudo apt-get update -y
	sudo apt-get install -y mpg123 git
fi


# Check SSH Keys
if [ ! -f "~/.ssh/id_rsa.pub" ]; then
	echo "SSH Key found. Please copy this key to the mainorder printer repository."
	echo -e "\n\n"
	cat ~/.ssh/id_rsa.pub
	echo -e "\n\n"
	proceed
else
	echo "No SSH Key present, I will create a new key now."
	ssh-keygen -f ~/.ssh/mainorder_ssh
	
	echo "Please copy this SSH key to the mainorder printer repository"
	echo -e "\n\n"
	cat ~/.ssh/mainorder_ssh.pub
	echo -e "\n\n"
	proceed
fi

# Start cloning process
if [ ! -d "$MAINORDER_INSTALL_DIR" ]; then
	echo "Cloning repository"
	git clone git@github.com:mainorder/printer.git "$MAINORDER_INSTALL_DIR"
	cd "$MAINORDER_INSTALL_DIR"
else
	echo "Repository found. Updating..."
	cd "$MAINORDER_INSTALL_DIR"
	git pull origin master
fi

echo "Installing App Dependencies"
pip3 install -r requirements.txt


if [[ "$MAINORDER_INTERACTIVE" == "1" && "yes" == $(confirm "Do you want to edit the configuration file using \$EDITOR ($EDITOR)?") ]]
then
	cp config.sample.cfg config.cfg
	$EDITOR config.cfg
fi

# Install Node & PM2
if ! command -v node &> /dev/null
then
    echo "Node could not be found."
	if [[ "$OSTYPE" == "linux-gnu"* && "yes" == $(confirm "Do you want to install node?") ]]
	then
		echo "Installing node. This may take a while..."
		install_node
	fi
fi

if ! command -v pm2 &> /dev/null
then
    echo "pm2 could not be found."
	if [[ "yes" == $(confirm "Do you want to install pm2?") ]]
	then
		echo "Installing pm2"
		npm install -g pm2
	fi
fi

# DataPlicity
if [[ "yes" == $(confirm "Do you want to setup dataplicity for remote control?") ]]
then
	echo "Setting up dataplicity..."
	curl -s "https://www.dataplicity.com/$MAINORDER_DATAPLICITY.py" | sudo python
fi


# Test run
# python3 main.py test
proceed

# Setup autostart
# DataPlicity
if [[ "yes" == $(confirm "Do you want to setup autostart?") ]]
then
	pm2 startup
	pm2 start "python3 main.py"
	pm2 save
fi

echo "MainOrder setup complete."
