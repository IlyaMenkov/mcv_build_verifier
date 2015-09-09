#!/bin/bash
#set-x

function controller_setup () {
    sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
    service ssh restart
}

function vm_setup () {
    sudo sed -i '/def check_and_fix_environment(self, required_containers):/a \\tself._fake_creds()' /opt/mcv-consoler/accessor.py
    #Set ip addresses for tests
    sudo sed -i s/172.16.57.37/$1/ /opt/mcv-consoler/accessor.py
    sudo sed -i s/172.16.57.41/$2/ /opt/mcv-consoler/accessor.py
    sudo sed -i s/172.16.57.35/$3/ /opt/mcv-consoler/accessor.py
    sudo sed -i s/172.16.57.34/172.16.0.1/ /opt/mcv-consoler/accessor.py
}

function vm_test () {
    sudo mcvconsoler --run custom default
    sudo mcvconsoler --run single rally neutron-create_and_list_routers.yaml
    sudo mcvconsoler --run custom full_mos
    sudo mcvconsoler --run custom full_load
    #for i in `ls /home/mcv/mcv-consoler/test_scenarios/rally/tests/ | grep yaml`; do sudo mcvconsoler --run single rally $i; done
}

function vm_reset () {
    sudo sed -i s/$1/172.16.57.37/ /opt/mcv-consoler/accessor.py
    sudo sed -i s/$2/172.16.57.41/ /opt/mcv-consoler/accessor.py
    sudo sed -i s/$3/172.16.57.35/ /opt/mcv-consoler/accessor.py
    sudo sed -i s/172.16.0.1/172.16.57.34/ /opt/mcv-consoler/accessor.py
    sudo sed -i '/self._fake_creds()/d' /opt/mcv-consoler/accessor.py
}

python main.py
# Setup ssh on controller
controller_setup

# Create image in glance
glance image-create --name mcv --disk-format qcow2 --container-format bare --is-public true --file mcv.qcow2 --progress

# Get network id from neutron
network_id=`neutron net-list | grep 'net04 ' | awk -F"|" {'print $2'} | awk '{ gsub (" ", "", $0); print}'`
# Boot VM
nova boot --image mcv --flavor m1.large --nic net-id=$network_id mcv_vm

# Get new float ip and add security groups
controller_ip_address=`ifconfig | grep 172 | awk -F":" {'print $2'} | cut -d' ' -f1 | head -n 1`
endpoint_ip_address=`keystone endpoint-list | grep 9292 | awk -F"|" {'print $4'} |  awk '{ gsub (" ", "", $0); print}' | awk -F":" {'print $2'} | cut -c 3-`
float_ip_address=`nova floating-ip-create | grep 'net04' | awk -F"|" {'print $3'} | awk '{ gsub (" ", "", $0); print}'`
nova floating-ip-associate mcv_vm $float_ip_address
nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
nova secgroup-add-rule default tcp 22 22 0.0.0.0/0

# Trying connect to VM using ssh
code=1
while [[ $code != 0 ]]; do
    sleep 15m
    #ssh mcv@$float_ip_address "$(typeset -f); vm_setup"
    ssh -t mcv@172.16.0.131 "$(typeset -f); echo mcv | vm_setup $controller_ip_address $float_ip_address $endpoint_ip_address; vm_test; vm_reset $controller_ip_address $float_ip_address $endpoint_ip_address"
    code=$?
done