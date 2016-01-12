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
    wget $1
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
    sudo scp -r /var/log/ root@$1:~/tmp
    sudo scp -r cli_output.log root@$1:~/tmp
    sudo scp -r results.log root@$1:~/tmp

}

#######################################################################################################################
# Functions for tests running
function vm_test_full_mos_load () {
    sudo -S mcvconsoler --run custom full_mos
    sudo -S mcvconsoler --run custom full_load
}

function vm_test_default () {
    # Running tests
    sudo mcvconsoler --run custom default &>>cli_output.log
    c=$?
    echo $c
    if [ $c -eq 0 ]; then echo "default test passed" &>>results.log; else echo "default test failed" &>>results.log; fi
    sudo mcvconsoler --run single rally neutron-create_and_list_routers.yaml &>>cli_output.log
    c=$?
    echo $c
    if [ $c -eq 0 ]; then echo "Single test passed" &>>results.log; else echo "Single test failed" &>>results.log; fi
    sudo mcvconsoler --run custom resources &>>cli_output.log
    c=$?
    echo $c
    if [ $c -eq 0 ]; then echo "resource test passed" &>>results.log; else echo "resoutce test failed" &>>results.log; fi
}

function vm_test_functional () {
    sudo mcvconsoler --run custom functional &>>cli_output.log
    c=$?
    if [ $c -eq 0 ]; then echo "Functional test passed" &>>results.log; else echo "functional test failed"&>>results.log; fi
}

function vm_test_smoke () {
    sudo mcvconsoler --run custom smoke &>>cli_output.log
    c=$?
    if [ $c -eq 0 ]; then echo "smoke test passed" &>>results.log; else echo "smoke test failed" &>>results.log; fi
}

function vm_test_ostf () {
    sudo -S mcvconsoler --run custom ostf_61
}

function vm_test_quick () {
    sudo mcvconsoler --run custom quick &>>cli_output.log
    c=$?
    if [ $c -eq 0 ]; then echo "quick test passed" &>>results.log ; else echo "quick test failed" &>>results.log; fi
}

# Running shaker test
function vm_test_shaker () {
    sudo -S mcvconsoler --run custom shaker &>>cli_output.log
    c=$?
    if [ $c -eq 0 ]; then echo "shaker test passed" &>>results.log; else echo "Shaker test failed" &>>results.log; fi

}

function self_test () {
    selfCheck=0
    b=directory
    # Check that /opt/mcv-consoler is exist
    a=`file /opt/mcv-consoler | awk {'print $2'}`
    if [[ $a -eq $b ]];
    then
        echo "consoler dirrectory - OK" >> selfCheck.log;
    else
        echo "consoler not over here /opt/mcv-consoler" >> selfCheck.log;
        selfCheck=1
    fi
    # Check that /opt/mcv-board exist
    a=`file /opt/mcv-board | awk {'print $2'}`
    if [[ $a -eq $b ]];
    then
        echo "consoler board exist - OK" >> selfCheck.log;
    else
        echo "consoler board not exist" >> selfCheck.log;
        selfCheck=1
    fi

    # Check that mcv.conf exist
    b=ASCII
    a=`file /etc/mcv/mcv.conf | awk {'print $2'}`
    if [[ $a -eq $b ]];
    then
        echo "mcv.conf exist - OK" >> selfCheck.log;
    else
        echo "mcv.conf not exist" >> selfCheck.log;
        selfCheck=1
    fi

    # Check that /etc/hosts exist
    #b=ASCII
    a=`file /etc/hosts | awk {'print $2'}`
    if [[ $a -eq $b ]];
    then
        echo "file hosts exist - OK" >> selfCheck.log;
    else
        echo "file hosts not exist" >> selfCheck.log;
        selfCheck=1
    fi

    dockers=(mcv-tempest mcv-rally mcv-wally mcv-ostf70 mcv-ostf61 mcv-shaker)
    for i in ${dockers[*]}
    do
        docker ps -a | grep Created | awk {'print $2'} | grep $i
        if [ $? -eq 1 ]; then echo "can not find docker $i"; selfCheck=1; fi
    done

    if [ selfCheck -eq 1 ]; then echo "self test failed"; sleep 2m; fi
}

# Export credentials
rd_cfg

# Download mcv image
download_mcv_image $image_link

# Setup ssh on controller
controller_setup

#######################################################################################################################
# Trying connect to VM using ssh and run tests
code=1
while [[ $code != 0 ]]; do
    sleep 5m # wait while vm deploying
    ssh -t mcv@$instance_ip "$(typeset -f); vm_setup $controller_ip $instance_ip $os_username $os_tenant_name $os_password $auth_endpoint_ip $nailgun_host $cluster_id 7.0; self_test; vm_test_default; save_logs $controller_ip;"
    code=$?
    echo $code
done

echo "image testing was finished"
echo "logs from mcv instance in mcv_build_verifier/logs/"
echo "results are saved in mcv_build_verifier/results.log"
