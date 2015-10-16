#!/bin/bash
#set-x

#######################################################################################################################
function controller_setup () {
    sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
    service ssh restart
}

function vm_setup () {
    #Set ip credentials for tests
    sudo sed -i '/\[basic\]/a instance_ip=172.16.0.131' /etc/mcv/mcv.conf
    sudo sed -i '/\[basic\]/a controller_ip=172.16.0.4' /etc/mcv/mcv.conf
    sudo sed -i '/\[basic\]/a auth_endpoint_ip=172.16.0.3' /etc/mcv/mcv.conf
    sudo sed -i '/\[basic\]/a nailgun_host=172.16.0.1' /etc/mcv/mcv.conf
    sudo sed -i '/\[basic\]/a os_username=admin' /etc/mcv/mcv.conf
    sudo sed -i '/\[basic\]/a os_tenant_name=admin' /etc/mcv/mcv.conf
    sudo sed -i '/\[basic\]/a os_password=admin' /etc/mcv/mcv.conf
    sudo sed -i '/\[basic\]/a cluster_id==1' /etc/mcv/mcv.conf
}

#######################################################################################################################
# Save logs from instance on my PC
function save_logs () {
    sudo scp -r /var/log/ imenkov@172.18.66.5:/tmp/test_logs
    c=$?
    if [ c!=0 ]
        then
            echo "LOG OK"
    fi
}

#######################################################################################################################
# Functions for tests rinning
function vm_test_full () {
    sudo mcvconsoler --run custom full_mos
    sudo mcvconsoler --run custom full_load
    c=$?
    if [ c!=0 ]
        then
            echo "full failed"
    fi

}

function vm_test_rally () {
    # Running tests
    sudo mcvconsoler --run custom default
    sudo mcvconsoler --run single rally neutron-create_and_list_routers.yaml
    c=$?
    if [ c!=0 ]
        then
            echo "rally default or single failed"
    fi
    #for i in `ls /opt/mcv-consoler/test_scenarios/rally/tests/ | grep load`; do sudo mcvconsoler --run single rally $i; done
}

function vm_test_ostf () {
    sudo mcvconsoler --run custom ostf
    c=$?
    if [ c!=0 ]
        then
            echo "ostf failed"
    fi
}

# Running shaker test
function vm_test_shaker () {
    sudo mcvconsoler --run custom shaker
    c=$?
    if [ c!=0 ]
        then
            echo "shaker failed"
    fi
}

#######################################################################################################################
#download image from google drive
python mcv_build_verifier/main.py

# Setup ssh on controller
controller_setup

# Create image in glance
glance image-create --name mcv --disk-format qcow2 --container-format bare --is-public true --file mcv.qcow2 --progress

# Get network id from neutron
network_id=`neutron net-list | grep 'net04 ' | awk -F"|" {'print $2'} | awk '{ gsub (" ", "", $0); print}'`

# Boot VM
nova boot --image mcv --flavor m1.large --nic net-id=$network_id mcv_vm

# Get controller ip address
controller_ip_address=`ifconfig | grep 172 | awk -F":" {'print $2'} | cut -d' ' -f1 | head -n 1`

# Get endpoint ip address
endpoint_ip_address=`keystone endpoint-list | grep 9292 | awk -F"|" {'print $4'} |  awk '{ gsub (" ", "", $0); print}' | awk -F":" {'print $2'} | cut -c 3-`

# Get new float ip and add security groups
float_ip_address=`nova floating-ip-create | grep 'net04' | awk -F"|" {'print $3'} | awk '{ gsub (" ", "", $0); print}'`
nova floating-ip-associate mcv_vm $float_ip_address
nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
#######################################################################################################################
# Trying connect to VM using ssh and run tests
code=1
while [[ $code != 0 ]]; do
    sleep 5m # wait while vm deploying
    #ssh -t mcv@172.16.0.131 "$(typeset -f); echo mcv | vm_setup $controller_ip_address $float_ip_address $endpoint_ip_address; vm_test"
    ssh -t mcv@$float_ip_address "$(typeset -f); echo mcv | vm_setup; vm_test_rally; vm_test_ostf; vm_test_shaker; save_logs;" &>>/tmp/mylogfile
    code=$?
done
scp -r /tmp/mylogfile imenkov@172.18.66.5:/tmp/test_logs/