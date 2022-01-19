#!/usr/bin/env bash

RESTORE='\033[0m'

RED='\033[00;31m'
GREEN='\033[00;32m'
YELLOW='\033[00;33m'
BLUE='\033[00;34m'
PURPLE='\033[00;35m'
CYAN='\033[00;36m'
LIGHTGRAY='\033[00;37m'

LRED='\033[01;31m'
LGREEN='\033[01;32m'
LYELLOW='\033[01;33m'
LBLUE='\033[01;34m'
LPURPLE='\033[01;35m'
LCYAN='\033[01;36m'
WHITE='\033[01;37m'

ipaddr=`python3 /srv/newsblur/utils/hostname_ssh.py $1 $2`
printf "\n ${BLUE}---> ${LBLUE}Connecting to ${LGREEN}$1${BLUE} / ${LRED}$ipaddr${BLUE} <--- ${RESTORE}\n\n"
if [ "$2" == "old" ];
then
    ssh -l sclay -i /srv/secrets-newsblur/keys/newsblur.key $ipaddr
else
    ssh -l nb -i /srv/secrets-newsblur/keys/docker.key $ipaddr
fi
