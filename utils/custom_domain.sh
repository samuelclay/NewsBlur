#!/bin/bash
#
# This script is written by a NewsBlur user, lineuctterx, and is unmaintained. Use at your own risk.
#

if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
  else
    if [ $# -eq 1 ]
     then
     echo "$(tput setaf 1)Changinging newsblur_web/docker_local_settings.py:$(tput setaf 2) localhost to $1$(tput sgr 0)"
     sed -i'.bak'  -e "/NEWSBLUR_URL/ s/localhost/$1/" -e "/SESSION_COOKIE_DOMAIN/ s/localhost/$1/" './newsblur_web/docker_local_settings.py'
     head -20 './newsblur_web/docker_local_settings.py'
     echo "$(tput setaf 1)Changinging config/fixtures/bootstrap.json:$(tput setaf 2) localhost to $1$(tput sgr 0)"
     sed -i'.bak' "/domain/ s/localhost/$1/" './config/fixtures/bootstrap.json'
     head -10 './config/fixtures/bootstrap.json'
    else
      if [ $# -eq 2 ]
      then
       echo "$(tput setaf 1)Changinging newsblur_web/docker_local_settings.py: $(tput setaf 2)$1 to $2$(tput sgr 0)"
       sed -i'bak' -e "/NEWSBLUR_URL/ s/$1/$2/" -e "/SESSION_COOKIE_DOMAIN/ s/$1/$2/" './newsblur_web/docker_local_settings.py' 
       head -20 './newsblur_web/docker_local_settings.py'
       echo "$(tput setaf 1)Changinging config/fixtures/bootstrap.json: $(tput setaf 2)$1 to $2$(tput sgr 0)"
       sed -i'bak' -e "/domain/ s/$1/$2/" './config/fixtures/bootstrap.json'
       head -10 './config/fixtures/bootstrap.json'
      fi
    fi
fi
