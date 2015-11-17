#!/bin/bash
#set-x

#######################################################################################################################
function controller_setup () {
    sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
    service ssh restart &>/tmp/filename
}

function vm_setup () {
    while read -r name
    do
    export $name
    echo -mcv | sudo -S sed -i '/\[basic\]/a'$name /etc/mcv/mcv.conf
    done < mcvbv.conf
}
#######################################################################################################################
# Save logs from instance on my PC
function save_logs () {
    echo -mcv | sudo scp -r /var/log/ imenkov@172.18.66.5:/tmp/test_logs
    c=$?
    if [ c!=0 ]
        then
            echo "LOG OK"
    fi
}

#######################################################################################################################
# Functions for tests running
function vm_test_full () {
    echo mcv | sudo -S mcvconsoler --run custom full_mos
    echo mcv | sudo -S mcvconsoler --run custom full_load
    c=$?
    if [ c!=0 ]
        then
            echo "full test failed"
    fi

}

function vm_test_rally () {
    # Running tests
    echo mcv | sudo -S mcvconsoler --run custom default
    echo mcv | sudo -S mcvconsoler --run single rally neutron-create_and_list_routers.yaml
    c=$?
    if [ c!=0 ]
        then
            echo "rally default or single failed"
    fi
    #for i in `ls /opt/mcv-consoler/test_scenarios/rally/tests/ | grep load`; do sudo mcvconsoler --run single rally $i; done
}

function vm_test_ostf () {
    echo mcv | sudo -S mcvconsoler --run custom ostf
    c=$?
    if [ c!=0 ]
        then
            echo "ostf failed"
    fi
}

# Running shaker test
function vm_test_shaker () {
    echo mcv | sudo -S mcvconsoler --run custom shaker
    c=$?
    if [ c!=0 ]
        then
            echo "shaker failed"
    fi
}

#######################################################################################################################
#download image from google drive
#python mcv_build_verifier/main.py
function download_mcv_image () {
    MY_IP='http://172.18.196.12:8000/'
    ISO_IMAGE=$(curl ${MY_IP} | grep qcow2 | tail -1 | awk '{print $2}' | cut -c 7- | awk -F"\"" {'print $1'})
    wget ${MY_IP}/${ISO_IMAGE}
}
# Setup ssh on controller
controller_setup

# Download mcv image
download_mcv_image

# Create image in glance
glance image-create --name mcv --disk-format qcow2 --container-format bare --is-public true --file $ISO_IMAGE --progress

# Get network id from neutron
network_id=`neutron net-list | grep 'net04 ' | awk -F"|" {'print $2'} | awk '{ gsub (" ", "", $0); print}'`

# Boot VM
nova boot --image mcv --flavor m1.large --nic net-id=$network_id mcv_vm

# Get new float ip and add security groups
instance_ip=`nova floating-ip-create | grep 'net04' | awk -F"|" {'print $3'} | awk '{ gsub (" ", "", $0); print}'`
nova floating-ip-associate mcv_vm $float_ip_address
nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
#######################################################################################################################
# Trying connect to VM using ssh and run tests
code=1
while [[ $code != 0 ]]; do
    sleep 5m # wait while vm deploying
    ssh -t mcv@$instance_ip "$(typeset -f); vm_setup; vm_test_rally; save_logs;"
    code=$?
done
scp -r /tmp/mylogfile imenkov@172.18.78.96:/tmp/test_logs/
