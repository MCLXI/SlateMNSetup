#!/bin/bash

# SLATE Masternode Setup Script V1.3 for Ubuntu 16.04 LTS

# (c) 2018 by Dwigt007 for Slate 

#

# Script will attempt to autodetect primary public IP address

# and generate masternode private key unless specified in command line

#

# Usage:

# bash slc-setup.sh [Masternode_Private_Key]

#

# Example 1: Existing genkey created earlier is supplied

# bash slc-setup.sh 27dSmwq9CabKjo2L3UD1HvgBP3ygbn8HdNmFiGFoVbN1STcsypy

#

# Example 2: Script will generate a new genkey automatically

# bash slc-setup.sh

#



#Color codes

RED='\033[0;91m'

GREEN='\033[1;32m'

YELLOW='\033[1;33m'

NC='\033[0m' # No Color



#Slate TCP port

PORT=52482



#Clear keyboard input buffer

function clear_stdin { while read -r -t 0; do read -r; done; }



#Delay script execution for N seconds

function delay { echo -e "${GREEN}Sleep for $1 seconds...${NC}"; sleep "$1"; }



#Stop daemon if it's already running

function stop_daemon {

    if pgrep -x 'slcd' > /dev/null; then

        echo -e "${YELLOW}Attempting to stop slcd${NC}"
	slc-cli stop
	delay 30

        if pgrep -x 'slcd' > /dev/null; then

            echo -e "${RED}slcd daemon is still running!${NC} \a"

            echo -e "${YELLOW}Attempting to kill...${NC}"

            pkill slcd

            delay 30

            if pgrep -x 'slcd' > /dev/null; then

                echo -e "${RED}Can't stop slcd! Reboot and try again...${NC} \a"

                exit 2

            fi

        fi

    fi

}



#Process command line parameters

genkey=$1



clear

echo -e "${YELLOW}SLATE Masternode Setup Script V1.3 for Ubuntu 16.04 LTS${NC}"

echo -e "${GREEN}Updating system and installing required packages...${NC}"

sudo DEBIAN_FRONTEND=noninteractive apt-get update -y



# Determine primary public IP address

dpkg -s dnsutils 2>/dev/null >/dev/null || sudo apt-get -y install dnsutils

publicip=$(dig +short myip.opendns.com @resolver1.opendns.com)



if [ -n "$publicip" ]; then

    echo -e "${YELLOW}IP Address detected:" $publicip ${NC}

else

    echo -e "${RED}ERROR:${YELLOW} Public IP Address was not detected!${NC} \a"

    clear_stdin

    read -e -p "Enter VPS Public IP Address: " publicip

    if [ -z "$publicip" ]; then

        echo -e "${RED}ERROR:${YELLOW} Public IP Address must be provided. Try again...${NC} \a"

        exit 1

    fi

fi



# update packages and upgrade Ubuntu

sudo apt-get -y upgrade
sudo apt-get -y dist-upgrade
sudo apt-get -y autoremove
sudo apt-get -y install wget nano htop jq
sudo apt-get -y install libzmq3-dev
sudo apt-get -y install libboost-system-dev libboost-filesystem-dev libboost-chrono-dev libboost-program-options-dev libboost-test-dev libboost-thread-dev
sudo apt-get -y install libevent-dev

sudo apt -y install software-properties-common
sudo add-apt-repository ppa:bitcoin/bitcoin -y
sudo apt-get -y update
sudo apt-get -y install libdb4.8-dev libdb4.8++-dev
sudo apt-get -y install libminiupnpc-dev
sudo apt-get -y install fail2ban
sudo service fail2ban restart
sudo apt-get install ufw -y
sudo apt-get update -y

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow $PORT/tcp
sudo ufw allow 52483/tcp
sudo ufw allow 22/tcp
sudo ufw limit 22/tcp
echo -e "${YELLOW}"

sudo ufw --force enable

echo -e "${NC}"

#Generating Random Password for slcd JSON RPC
rpcpassword=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

#Create 2GB swap file
if grep -q "SwapTotal" /proc/meminfo; then

    echo -e "${GREEN}Skipping disk swap configuration...${NC} \n"

else

    echo -e "${YELLOW}Creating 2GB disk swap file. \nThis may take a few minutes!${NC} \a"

    touch /var/swap.img

    chmod 600 swap.img

    dd if=/dev/zero of=/var/swap.img bs=1024k count=2000

    mkswap /var/swap.img 2> /dev/null

    swapon /var/swap.img 2> /dev/null

    if [ $? -eq 0 ]; then

        echo '/var/swap.img none swap sw 0 0' >> /etc/fstab

        echo -e "${GREEN}Swap was created successfully!${NC} \n"

    else

        echo -e "${YELLOW}Operation not permitted! Optional swap was not created.${NC} \a"

        rm /var/swap.img

    fi
fi

#Installing Daemon

cd ~

#sudo rm slc-qt-wallet-1.0.1-linux.zip
#wget https://github.com/slateprojectteam/slate-core-wallet/releases/download/1.0.1/slc-qt-wallet-1.0.1-linux.zip
#sudo tar -xzvf slc-qt-wallet-1.0.1-linux.zip --strip-components 1 --directory /usr/bin
#sudo rm slc-qt-wallet-1.0.1-linux.zip

stop_daemon

# Deploy binaries to /usr/bin

sudo cp SlateMasternodeSetup/slc-qt-wallet-1.0.1-linux/slc* /usr/bin/
sudo chmod 755 -R ~/SlateMasternodeSetup
sudo chmod 755 /usr/bin/slc*

# Deploy masternode monitoring script

cp ~/SlateMasternodeSetup/nodemon.sh /usr/local/bin
sudo chmod 711 /usr/local/bin/nodemon.sh

#Create slate datadir

if [ ! -f ~/.slc/slc.conf ]; then 

	sudo mkdir ~/.slc
fi

echo -e "${YELLOW}Creating slc.conf...${NC}"

# If genkey was not supplied in command line, we will generate private key on the fly

if [ -z $genkey ]; then

    cat <<EOF > ~/.slc/slc.conf

rpcuser=rpcuser
rpcpassword=$rpcpassword

EOF



    sudo chmod 755 -R ~/.slc/slc.conf



    #Starting daemon first time just to generate masternode private key

    slcd -daemon

    delay 30



    #Generate masternode private key

    echo -e "${YELLOW}Generating masternode private key...${NC}"

    genkey=$(slc-cli masternode genkey)

    if [ -z "$genkey" ]; then

        echo -e "${RED}ERROR:${YELLOW}Can not generate masternode private key.$ \a"

        echo -e "${RED}ERROR:${YELLOW}Reboot VPS and try again or supply existing genkey as a parameter."

        exit 1

    fi

    

    #Stopping daemon to create slc.conf

    stop_daemon

    delay 30

fi



# Create slc.conf

cat <<EOF > ~/.slc/slc.conf

rpcuser=rpcuser
rpcpassword=$rpcpassword
rpcallowip=127.0.0.1
onlynet=ipv4
rpcport=52483
listen=1
server=1
daemon=1
maxconnections=64
externalip=$publicip
masternode=1
masternodeprivkey=$genkey

EOF



#Finally, starting slate daemon with new slc.conf

slcd
delay 5



#Setting auto star cron job for slcd

cronjob="@reboot sleep 30 && slcd"
crontab -l > tempcron
if ! grep -q "$cronjob" tempcron; then

    echo -e "${GREEN}Configuring crontab job...${NC}"

    echo $cronjob >> tempcron

    crontab tempcron

fi

rm tempcron



echo -e "========================================================================

${YELLOW}Masternode setup is complete!${NC}

========================================================================

Masternode was installed with VPS IP Address: ${YELLOW}$publicip${NC}

Masternode Private Key: ${YELLOW}$genkey${NC}

Now you can add the following string to the masternode.conf file
for your Hot Wallet (the wallet with your Slate collateral funds):

======================================================================== \a"

echo -e "${YELLOW}mn1 $publicip:$PORT $genkey TxId TxIdx${NC}"

echo -e "========================================================================

Use your mouse to copy the whole string above into the clipboard by
tripple-click + single-click (Dont use Ctrl-C) and then paste it 
into your ${YELLOW}masternode.conf${NC} file and replace:

    ${YELLOW}mn1${NC} - with your desired masternode name (alias)

    ${YELLOW}TxId${NC} - with Transaction Id from masternode outputs

    ${YELLOW}TxIdx${NC} - with Transaction Index (0 or 1)

     Remember to save the masternode.conf and restart the wallet!

To introduce your new masternode to the Slate network, you need to
issue a masternode start command from your wallet, which proves that
the collateral for this node is secured."

clear_stdin
read -p "*** Press any key to continue ***" -n1 -s

echo -e "1) Wait for the node wallet on this VPS to sync with the other nodes
on the network. Eventually the 'IsSynced' status will change
to 'true', which will indicate a comlete sync, although it may take
from several minutes to several hours depending on the network state.

Your initial Masternode Status may read:

    ${YELLOW}Node just started, not yet activated${NC} or

    ${YELLOW}Node  is not in masternode list${NC}, which is normal and expected.

2) Wait at least until 'IsBlockchainSynced' status becomes 'true'.
At this point you can go to your wallet and issue a start
command by either using Debug Console:

    Tools->Debug Console-> enter: ${YELLOW}masternode start-alias mn1${NC}

    where ${YELLOW}mn1${NC} is the name of your masternode (alias)

    as it was entered in the masternode.conf file
    or by using wallet GUI:

    Masternodes -> Select masternode -> RightClick -> ${YELLOW}start alias${NC}

Once completed step (2), return to this VPS console and wait for the
Masternode Status to change to: 'Masternode successfully started'.
This will indicate that your masternode is fully functional and
you can celebrate this achievement!

Currently your masternode is syncing with the Slate network...

The following screen will display in real-time
the list of peer connections, the status of your masternode,
node synchronization status and additional network and node stats.

"
clear_stdin
read -p "*** Press any key to continue ***" -n1 -s

echo -e "
${GREEN}...scroll up to see previous screens...${NC}

Here are some useful commands and tools for masternode troubleshooting:
========================================================================
To view masternode configuration produced by this script in slc.conf:

      ${YELLOW}cat ~/.slc/slc.conf${NC}
Here is your slc.conf generated by this script:
-------------------------------------------------${YELLOW}"

cat ~/.slc/slc.conf

echo -e "${NC}-------------------------------------------------



NOTE: To edit slc.conf, first stop the slcd daemon,
then edit the slc.conf file and save it in nano: (Ctrl-X + Y + Enter),
then start the slcd daemon back up:

to stop:   ${YELLOW}slc-cli stop${NC}

to edit:   ${YELLOW}nano ~/.slc/slc.conf${NC}

to start:  ${YELLOW}slcd${NC}

========================================================================
To view slcd debug log showing all MN network activity in realtime:

${YELLOW}tail -f ~/.slc/debug.log${NC}

========================================================================
To monitor system resource utilization and running processes:
                     ${YELLOW}htop${NC}

========================================================================
To view the list of peer connections, status of your masternode, 
sync status etc. in real-time, run the nodemon.sh script:

${YELLOW}nodemon.sh${NC}

or just type 'node' and hit <TAB> to autocomplete script name.
========================================================================

Enjoy your Slate Masternode and thanks for using this setup script!

Authors : Allroad [fasterpool] . Dwigt007

...and make sure to check back for updates!

"
delay 30
# Run nodemon.sh

nodemon.sh