#!/bin/bash
#
# What is that
# ============
#
# This script will help you setting up your digital ocean
# infrastructure with Ansible v2.0+ and DO API v2
#
# Usually, when working with DO, one is supposed to use digital_ocean.py
# inventory file, and spin up instances in a playbook.
# However, this approach is very inconvenient for several reasons:
# - it is veeeery slow
# - your droplets won't have "ansible" names, just IPs
# - ... consequently, putting them into groups is a pain (but doable)
# - but if you succeed doing so, groups will only be available at run time
# - you are required to have 'localhost' in your inventory, which basically ruins 'all' group purpose
# - etc...
# All in all, it is barely usable.
#
# This script attempts to make things easier. It works the following way:
#
# - it will read 'hosts' file in an inventory directory (passed as the first argument)
# - it will spin up a DO droplet for each of these hosts (in parallel !) using ansible
# (note that you can specify image type, droplet size, etc... in the inventory itself)
# - it will generate an complementary inventory file (in the inventory
# directory) containing droplets names along with their IP addresses, so you
# won't need hitting the DO API anymore when running ansible.

# Using this script, you can work like you use to do with bare metal machines,
# without the chicken and egg problem of network configuration)
# The script itself can:
# - spin up droplets (`do_boot2.sh inventory_directory_path`)
# - destroy droplets (`do_boot2.sh inventory_directory_path deleted`) 

# Since the droplets are created in parallel, you will also save tons of time
# when building an infrastructure involving a bunch of droplets. As an example,
# creating 8 droplets takes 130 seconds using this script, almost 570 using a
# "classic approach". Destroying them takes 10 secs with this script, 55 using
# a classic approach. So in the end, you get a 5 fold speed up, and a much
# better usability. Of course, the more droplets, the more gain.
#
# DO_API_TOKEN environment variable must be set.
#
# Change defaults below
# ---------------------

# Digital Ocean default values
# You can override them using do_something in your inventory file
# Example:
# 
# [www]
# www1 do_size_slug="1gb" do_region_slug="nyc1" do_image=12345
# ...
#
# If you don't override in your inventory, the defaults below will apply
DEFAULT_SIZE="1gb"   # 512mb (override with do_size_slug)
DEFAULT_REGION="nyc3" # ams2 (override with do_region_slug)
DEFAULT_IMAGE="ubuntu-20-04-x64" # Ubuntu 14.04 x64 (override with do_image_slug)
DEFAULT_KEY=29426876    # SSH key, change this ! (override with do_key)

# localhost entry for temporary inventory
# This is a temp inventory generated to start the DO droplets
# You might want to change ansible_python_interpreter
LOCALHOST_ENTRY="localhost ansible_python_interpreter=/usr/bin/python3" 

# Set state to present by default
STATE=${2:-"present"}

# digital_ocean module command to use
# name, size, region, image and key will be filled automatically
COMMAND="state=$STATE command=droplet private_networking=yes unique_name=yes"
# ---------------------

function bail_out {
  echo -e "\033[0;31m"
  echo $1
  echo -e "\033[0m"
  echo -e "Usage: $0 <inventory_directory> [present|deleted]\n"
  echo -e "\tinventory_directory: the directory containing the inventory goal (compulsory)"
  echo -e "\tpresent: the droplet will be created if it doesn't exist (default)"
  echo -e "\tdeleted: the droplet will be destroyed if it exists\n"
  exit 1
}

# Check that inventory is a directory
# We need this since we generate a complementary inventory with IP addresses for hosts
INVENTORY=$1
[[ ! -d "$INVENTORY" ]]  && bail_out "Inventory does not exist, is not a directory, or is not set"
[[ -z "$DO_API_TOKEN" ]] && bail_out "DO_API_TOKEN not set. Please visit https://cloud.digitalocean.com/settings/applications"

JQ=`which jq` || bail_out "Unable to find required binary 'jq'. Please install it first (http://stedolan.github.io/jq/)"

# Get a list of hosts from inventory dir
HOSTS=$(ansible -i $1 --list-hosts all | awk '{ print $1 }' | tr '\n' ' ')

# Clean up previously generated inventory
rm ${INVENTORY}/generated > /dev/null 2>&1

# Creating temporary inventory with only localhost in it
TEMP_INVENTORY=$(mktemp)
echo Creating temporary inventory in ${TEMP_INVENTORY}
echo ${LOCALHOST} > ${TEMP_INVENTORY}

# Create droplets in //
for i in ${HOSTS}; do 
  SIZE=$(grep $i $1/hosts | grep do_size_slug | sed -e 's/.*do_size_slug=\(\d*\)/\1/')
  REGION=$(grep $i $1/hosts | grep do_region_slug | sed -e 's/.*do_region_slug=\(\d*\)/\1/')
  IMAGE=$(grep $i $1/hosts | grep do_image_slug | sed -e 's/.*do_image_slug=\(\d*\)/\1/')
  KEY=$(grep $i $1/hosts | grep do_key | sed -e 's/.*do_key=\(\d*\)/\1/')

  SIZE=${SIZE:-$DEFAULT_SIZE}
  REGION=${REGION:-$DEFAULT_REGION}
  IMAGE=${IMAGE:-$DEFAULT_IMAGE}
  KEY=${KEY:-$DEFAULT_KEY}

  if [ "${STATE}" == "present" ]; then
    echo "Creating $i of size $SIZE using image $IMAGE in region $REGION with key $KEY"
  else
    echo "Deleting $i"
  fi
  # echo " => $COMMAND name=$i size_id=$SIZE image_id=$IMAGE region_id=$REGION ssh_key_ids=$KEY"
  ansible localhost -c local -i ${TEMP_INVENTORY} -m digital_ocean \
    -a "$COMMAND name=$i size_id=$SIZE image_id=$IMAGE region_id=$REGION ssh_key_ids=$KEY" &
done

wait

# Now do it again to fill up complementary inventory
if [ "${STATE}" == "present" ]; then
  for i in ${HOSTS}; do 
    echo Checking droplet $i
    IP=$(ansible localhost -c local -i $TEMP_INVENTORY -m digital_ocean -a "state=present command=droplet unique_name=yes name=$i" | sed -e 's/localhost | success >> //' | $JQ '.droplet.networks.v4[] | select(.type == "public") | .ip_address' | cut -f2 -d'"')
    echo "$i ansible_ssh_host=$IP" >> ${INVENTORY}/generated
  done
fi

echo "All done !"
