#!/bin/bash
set -x

#######################################################################################################################
# Set up functions for controller and mcv instance
#read config

# we have next variables
# from mcvbv.conf
#controller_ip                      - for connect on controller, also change in mcv image
#os_username=admin                  - for mcv config
#os_tenant_name=admin               - for mcv config
#os_password=admin                  - for mcv config
#auth_endpoint_ip=172.16.0.3        - for mcv config
#nailgun_host=172.16.0.1            - for mcv config
#cluster_id=4                       - for mcv config
#version=7.0                        - for mcv config
#image_url=image_url                - for mcv config
#ssh_key_loc=/path/to/key           - for mcv config
# other
# image_name                        -for using on controller
function rd_cfg () {
    # read and export all creds from mcvbv.conf
    while read -r name
    do
    export $name
    done < mcvbv.conf

    # check image location
    if [ -z ${IMG_LOCATION+x} ]
    then
        echo "Using config file $image_url"
    else
        echo "using IMG_LOCATION=$IMG_LOCATION"
        export image_url=$IMG_LOCATION
    fi
    export image_name=$image_url | awk -F"/" {'print $NF'}

    # check ssh key location
    if [ -z ${SSH_KEY_LOCATION+x} ]
    then
        echo "Using config file, path to key: $ssh_key_loc"
    else
        echo "using ssh_hey_locationm path to key: $SSH_KEY_LOCATION"
        export ssh_key_loc=$SSH_KEY_LOCATION
    fi

    if [ -z ${instance_ip+x} ]
    then
        echo "instance_ip doesn't set in mcvbv.conf"
        instance_ip="0"
    fi
}


# this function will run when we are already connected to master node or when we have ssh key from master node
function controller_ssh () {
    ssh -o StrictHostKeyChecking=no -i $ssh_key_loc root@$controller_ip -t "$(typeset -f); \
        download_mcv_image $image_url; controller_setup $controller_ip $instance_ip $os_username \
        $os_tenant_name $os_password $auth_endpoint_ip $nailgun_host $cluster_id $version $private_endpoint_ip \
        $image_name"
}

# Get mcv image from url
function download_mcv_image () {
    wget $1
}


function controller_setup () {

    controller_ip=$1
   # instance_ip=$2
    os_username=$2
    os_tenant_name=$3
    os_password=$4
    auth_endpoint_ip=$5
    nailgun_host=$6
    cluster_id=$7
    version=$8
    #private_endpoint_ip=$10
    image_name=$9

    . openrc
    sudo apt-get install sshpass
    # change PasswordAuthentication for correct work MCV tool
    sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
    service ssh restart

    # Create image in glance
    glance image-create --name mcv --disk-format qcow2 --container-format bare --is-public true --file $image_name --progress

    # Get network id from neutron
    network_id=`neutron net-list | grep 'net04 ' | awk -F"|" {'print $2'} | awk '{ gsub (" ", "", $0); print}'`
    echo $network_id
    # Boot VM
    nova boot --image mcv --flavor m1.large --nic net-id=$network_id mcv_vm

    # Create and attach floating ip for instance

    #instance_ip=`nova floating-ip-list | grep ext | awk -F"|" '{print $3}' | sed 's/^.//'`
    if [ instance_ip == "0" ]
    then
        instance_ip=`nova floating-ip-create | grep 'net04' | awk -F"|" {'print $3'} | awk '{ gsub (" ", "", $0); print}'`
    fi
    nova floating-ip-associate mcv_vm $instance_ip
    #add security groups
    nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
    nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
    vm_ssh $controller_ip $instance_ip $os_username $os_tenant_name $os_password $auth_endpoint_ip $nailgun_host \
           $cluster_id $version
}

#######################################################################################################################
# Trying connect to VM using ssh and run tests
function vm_ssh () {
code=1
while [[ $code != 0 ]]; do
  #  sleep 5 # wait while vm deploying
    sshpass -p mcv ssh -o StrictHostKeyChecking=no -t mcv@$2 "$(typeset -f); vm_setup $1 $2 $3 $4 $5 $6 $7 $8 $9; self_test; vm_test_full"
    code=$?
    echo $code
done
}

#$controller_ip $os_username $os_tenant_name $os_password $auth_endpoint_ip $nailgun_host $cluster_id $version $image_url $image_name
# change creds in /etc/mcv/mcv.conf on mcv instance
function vm_setup () {
    sudo sed -i "/\[basic\]/acontroller_ip=$1" /etc/mcv/mcv.conf
    sudo sed -i "/\[basic\]/ainstance_ip=$2" /etc/mcv/mcv.conf
    sudo sed -i "/\[basic\]/aos_username=$3" /etc/mcv/mcv.conf
    sudo sed -i "/\[basic\]/aos_tenant_name=$4" /etc/mcv/mcv.conf
    sudo sed -i "/\[basic\]/aos_password=$5" /etc/mcv/mcv.conf
    sudo sed -i "/\[basic\]/aauth_endpoint_ip=$6" /etc/mcv/mcv.conf
    sudo sed -i "/\[basic\]/anailgun_host=$7" /etc/mcv/mcv.conf
    sudo sed -i "/\[basic\]/acluster_id=$8" /etc/mcv/mcv.conf
    sudo sed -i "s/version=6.1/version=$9/" /etc/mcv/mcv.conf
  #  sudo sed -i "s/private_endpoint_ip=192.168.0.2/private_endpoint_ip=$10" /etc/mcv/mcv.conf

}

#######################################################################################################################
# Save logs from instance
#function save_logs () {
#    sudo scp -r /var/log/ root@$1:~/tmp
#    sudo scp -r cli_output.log root@$1:~/tmp
#    sudo scp -r results.log root@$1:~/tmp
#
#}

#######################################################################################################################
# Functionm for tests running
function vm_test_full () {
    sudo mcvconsoler --run custom default &>>cli_output.log
    c=$?; echo $c
    if [ $c -eq 0 ]; then echo "default test passed"; else echo "default test failed" &>>results.log; fi
    sudo mcvconsoler --run single rally neutron-create_and_list_routers.yaml &>>cli_output.log
    c=$?; echo $c
    if [ $c -eq 0 ]; then echo "Single test passed"; else echo "Single test failed" &>>results.log; fi
    sudo mcvconsoler --run custom resources 
    c=$?; echo $c
    if [ $c -eq 0 ]; then echo "resource test passed"; else echo "resoutce test failed"; fi
    c=$?; echo $c

#    sudo mcvconsoler --run custom functional &>>cli_output.log
#    c=$?; echo $c
#    if [ $c -eq 0 ]; then echo "Functional test passed" &>>results.log; else echo "functional test failed"&>>results.log; fi

    sudo mcvconsoler --run custom smoke &>>cli_output.log
 #   c=$?; echo $c
 #   if [ $c -eq 0 ]; then echo "smoke test passed" &>>results.log; else echo "smoke test failed" &>>results.log; fi
#
#    sudo mcvconsoler --run custom quick &>>cli_output.log
#    c=$?; echo $c
#    if [ $c -eq 0 ]; then echo "quick test passed" &>>results.log ; else echo "quick test failed" &>>results.log; fi
#
    sudo -S mcvconsoler --run custom shaker &>>cli_output.log
    c=$?; echo $c
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

    if [ selfCheck -eq 1 ]; then echo "self test failed"; fi
}




# Setup ssh on controller
#-----------------------------------------------------------------------------------------------------------------------
# just RUNNING
# Export credentials
rd_cfg
# connect to controller and etc
controller_ssh $ssh_key_loc
