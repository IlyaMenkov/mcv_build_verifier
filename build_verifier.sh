#!/bin/bash
set-x

#######################################################################################################################

# Set up functions for controller and mcv instance
#read config
function rd_cfg () {
    while read -r name
    do
    export $name
    done < mcvbv.conf
}

function download_mcv_image () {
    MY_IP='http://172.18.160.121:9000/'
    ISO_IMAGE=$(curl ${MY_IP} | grep qcow2 | tail -1 | awk '{print $2}' | cut -c 7- | awk -F"\"" {'print $1'})
    wget ${MY_IP}/${ISO_IMAGE}
}

function controller_setup () {
    sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
    service ssh restart &>/tmp/filename

    # Create image in glance
    c=$?
    glance image-create --name mcv --disk-format qcow2 --container-format bare --is-public true --file $ISO_IMAGE --progress
    if [ c!=0 ];then  exit 1; fi
    # Get network id from neutron
    network_id=`neutron net-list | grep 'net04 ' | awk -F"|" {'print $2'} | awk '{ gsub (" ", "", $0); print}'`
    if [ c!=0 ];then  exit 1; fi
    # Boot VM
    nova boot --image mcv --flavor m1.large --nic net-id=$network_id mcv_vm
    if [ c!=0 ];then  exit 1; fi
    # Get new float ip and add security groups
   # instance_ip=`nova floating-ip-create | grep 'net04' | awk -F"|" {'print $3'} | awk '{ gsub (" ", "", $0); print}'`
    nova floating-ip-associate mcv_vm $instance_ip
    nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
    nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
}

function vm_setup () {
    sudo -S sed -i '/\[basic\]/a'$controller_ip /etc/mcv/mcv.conf
    sudo -S sed -i '/\[basic\]/a'$instance_ip /etc/mcv/mcv.conf
    sudo -S sed -i '/\[basic\]/a'$os_username /etc/mcv/mcv.conf
    sudo -S sed -i '/\[basic\]/a'$os_tenant_name /etc/mcv/mcv.conf
    sudo -S sed -i '/\[basic\]/a'$os_password /etc/mcv/mcv.conf
    sudo -S sed -i '/\[basic\]/a'$auth_endpoint_ip /etc/mcv/mcv.conf
    sudo -S sed -i '/\[basic\]/a'$nailgun_host /etc/mcv/mcv.conf
    sudo -S sed -i '/\[basic\]/a'$cluster_id /etc/mcv/mcv.conf
#    while read -r name
 #   do
  #  export $name
   #
    #done < mcvbv.conf
}

#######################################################################################################################
# Save logs from instance on my PC
function save_logs () {
    sudo scp -r /var/log/ imenkov@172.18.78.96:/tmp/test_logs
}

#######################################################################################################################
# Functions for tests running
function vm_test_full () {
    sudo -S mcvconsoler --run custom full_mos
    sudo -S mcvconsoler --run custom full_load
}

function vm_test_rally () {
    # Running tests
    sudo -S mcvconsoler --run custom default
    sudo -S mcvconsoler --run single rally neutron-create_and_list_routers.yaml
}

function vm_test_ostf () {
    sudo -S mcvconsoler --run custom ostf_61
}

# Running shaker test
function vm_test_shaker () {
    sudo -S mcvconsoler --run custom shaker
}

#######################################################################################################################
#download image from google drive
#python mcv_build_verifier/main.py


# Export credentials
rd_cfg

# Download mcv image
download_mcv_image

# Setup ssh on controller
controller_setup


#######################################################################################################################
# Trying connect to VM using ssh and run tests
code=1
while [[ $code != 0 ]]; do
    sleep 5m # wait while vm deploying
    ssh-keygen -f "/root/.ssh/known_hosts" -R $instance_ip
    ssh -t mcv@$instance_ip "$(typeset -f); vm_setup; vm_test_rally; save_logs;"
    code=$?
done
scp -r /tmp/mylogfile imenkov@172.18.78.96:/tmp/test_logs/
