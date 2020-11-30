#!/bin/bash

set -euxo pipefail

# System dependencies
REQUIRED_PYTHON_VERSION="3.4.0"
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
	echo "Installing python 3.6.0..."
	sudo apt-get install build-essential libc6-dev
	sudo apt-get install libncurses5-dev libncursesw5-dev libreadline6-dev
	sudo apt-get install libdb5.3-dev libgdbm-dev libsqlite3-dev libssl-dev
	sudo apt-get install libbz2-dev libexpat1-dev liblzma-dev zlib1g-dev


	cd $HOME
	wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-3.6.0.tgz
	tar -zxvf Python-3.6.0.tgz
	cd Python-3.6.0
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

if [[ "$PYTHON_VERSION" -lt "34" ]]
then
	echo "Python >=3.4 not installed. "
	if [[ "$OSTYPE" == "linux-gnu"* && "yes" == $(confirm "Do you want to install python3.6?") ]]
	then
		echo "Installing python 3.6. This may take a while..."
		install_python_36
	fi
	exit
fi

echo "Python >= 3.4 installed. Setting up git project."

# Dependencies
echo "Installing dependencies"

if [[ "$OSTYPE" == "linux-gnu"* ]]
then
	sudo apt-get update -y
	sudo apt-get install -y mpg123 git libopenjp2-7-dev
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
pip3 install --user -r requirements.txt
pip3 install --user schedule
pip3 install --user paramiko
# reinstall these to enforce up to date version
sudo pip3 uninstall python-escpos
pip3 install --user python-escpos


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
		sudo npm install -g pm2
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

# Bus 001 Device 004: ID 04b8:0e15 Seiko Epson Corp. 
echo 'ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="04b8", ATTR{idProduct}=="0e15", MODE="0666"' > /etc/udev/rules.d/99-epson.rules

# Setup autostart

# DataPlicity
if [[ "yes" == $(confirm "Do you want to setup autostart?") ]]
then
	pm2 startup
	pm2 start "bash start.sh"
	pm2 save
fi

echo "MainOrder setup complete."
