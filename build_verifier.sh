#!/bin/bash
set -x

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

    #if [ c!=0 ];then  exit 1; fi
    # Get network id from neutron
    network_id=`neutron net-list | grep 'net04 ' | awk -F"|" {'print $2'} | awk '{ gsub (" ", "", $0); print}'`

    #if [ c!=0 ];then  exit 1; fi
    # Boot VM
    nova boot --image mcv --flavor m1.large --nic net-id=$network_id mcv_vm
    # Get new float ip and add security groups

    #Create floating ip for instance
   # instance_ip=`nova floating-ip-create | grep 'net04' | awk -F"|" {'print $3'} | awk '{ gsub (" ", "", $0); print}'`


    nova floating-ip-associate mcv_vm $instance_ip
    nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
    nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
}

function vm_setup () {
    sudo sed -i "/\[basic\]/acontroller_ip=$1" /etc/mcv/mcv.conf
    sudo sed -i "/\[basic\]/ainstance_ip=$2" /etc/mcv/mcv.conf
    sudo sed -i "/\[basic\]/aos_username=$3" /etc/mcv/mcv.conf
    sudo sed -i "/\[basic\]/aos_tenant_name=$4" /etc/mcv/mcv.conf
    sudo sed -i "/\[basic\]/aos_password=$5" /etc/mcv/mcv.conf
    sudo sed -i "/\[basic\]/aauth_endpoint_ip=$6" /etc/mcv/mcv.conf
    sudo sed -i "/\[basic\]/anailgun_host=$7" /etc/mcv/mcv.conf
    sudo sed -i "/\[basic\]/acluster_id=$8" /etc/mcv/mcv.conf
    sudo sed -i "s/version=6.1/version=$9/" /etc/ssh/sshd_config
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

function vm_test_default () {
    # Running tests
    sudo mcvconsoler --run custom default &>>cli_output.log
    c=$?
    echo $c
    if ( $c==0 ); then echo "Default test passed" ; else "Default test failed"; fi
    sudo mcvconsoler --run single rally neutron-create_and_list_routers.yaml &>>cli_output.log
    c=$?
    echo $c
    if ( $c==0 ); then echo "Single test passed" ; else "Single test failed"; fi
    sudo mcvconsoler --run custom resources &>>cli_output.log
    c=$?
    echo $c
    if ( $c==0 ); then echo "resources test passed" ; else "resources test failed"; fi
}

function vm_test_functional () {
    sudo mcvconsoler --run custom functional &>>cli_output.log
    c=$?
    if ( $c==0 ); then echo "Functional test passed" ; else "Functional test failed";fi
}

function vm_test_smoke () {
    sudo mcvconsoler --run custom smoke &>>cli_output.log
    c=$?
    if ( $c==0 ); then echo "Smoke test passed" ; else "Smoke test failed";fi
}

function vm_test_ostf () {
    sudo -S mcvconsoler --run custom ostf_61
}

function vm_test_quick () {
    sudo mcvconsoler --run custom quick &>>cli_output.log
    c=$?
    if ( $c==0 ); then echo "Quick test passed" ;else echo "Quick test failed";fi
}

# Running shaker test
function vm_test_shaker () {
    sudo -S mcvconsoler --run custom shaker &>>cli_output.log
    c=$?
    if ( $c==0 ); then echo "Shaker test passed" ;else "Shaker test failed";fi

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

    ssh -t mcv@$instance_ip "$(typeset -f); vm_setup $controller_ip $instance_ip $os_username $os_tenant_name $os_password $auth_endpoint_ip $nailgun_host $cluster_id 7.0; vm_test_default"
    code=$?
done
scp -r /tmp/mylogfile imenkov@172.18.78.96:/tmp/test_logs/