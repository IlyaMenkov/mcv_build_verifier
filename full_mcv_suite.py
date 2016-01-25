from __future__ import print_function
from oslo.config import cfg
import paramiko
import time
opt_group = cfg.OptGroup(name='basic',
                         title='mcvbv.conf')
simple_opts = [
    cfg.StrOpt('controller_ip', default='172.16.0.4',
                help=('one of controllers ip fuel nodes on master node')),
    cfg.StrOpt('os_username', default='admin',
                help=('True enables, False disables')),
    cfg.StrOpt('os_tenant_name', default='admin',
                help=('True enables, False disables')),
    cfg.StrOpt('os_password', default='admin',
                help=('True enables, False disables')),
    cfg.StrOpt('auth_endpoint_ip', default='172.16.0.3',
                help=('keystone endpoint-list on controller')),
    cfg.StrOpt('nailgun_host', default='172.16.1.1',
                help=('nailgun ip fuel nodes on master node')),
    cfg.StrOpt('cluster_id', default='1',
                help=('cluster ID from master node')),
    cfg.StrOpt('version', default='7.0',
                help=('MOS version')),
    cfg.StrOpt('private_endpoint_ip', default='172.16.0.3',
                help=('private endpoint ip')),
    cfg.StrOpt('image_url', default='http://localhost/mcv.image.qcow2',
                help=('')),
    cfg.StrOpt('ssh_key_loc', default='.ssh/id_rsa',
                help=('path to master node id_rsa'))
]

CONF = cfg.CONF
CONF.register_group(opt_group)
CONF.register_opts(simple_opts, opt_group)

if __name__ == "__main__":
    CONF(default_config_files=['mcvbv.conf'])
    print('test use next credentials: ')
    print(CONF.basic.controller_ip)
    print(CONF.basic.os_username)
    print(CONF.basic.os_tenant_name)
    print(CONF.basic.os_password)
    print(CONF.basic.auth_endpoint_ip)
    print(CONF.basic.nailgun_host)
    print(CONF.basic.cluster_id)
    print(CONF.basic.version)
    print(CONF.basic.private_endpoint_ip)
    print(CONF.basic.image_url)
    print(CONF.basic.ssh_key_loc)

    # getting image name from image url
    ControllerImagePath='/var/lib/mysql/images/' + str(CONF.basic.image_url.split('/')[-1])

    # understanding what we need to use: wget or just path to mcv image
    if CONF.basic.image_url[0:4]=='http':
        getting_image_command="wget " + str(CONF.basic.image_url) + " -P /var/lib/mysql/images/ >> controller_log.log"
    else:
        getting_image_command="echo use path to image >> controller_log.log"

# work with controller
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(CONF.basic.controller_ip, username='root', password='r00tme', key_filename='/tmp/id_rsa')
    qqq, www, eee = ssh.exec_command(
                                     '%s &&'
                                     '. openrc >> controller_log.log &&'
                                     'sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config >> controller_log.log &&'
                                     'service ssh restart >> controller_setups.log &&'
                                     'glance image-create --name mcv --disk-format qcow2 --container-format bare --is-public true --file %s --progress >> controller_log.log &&'
                                     'network_id=`neutron net-list | grep \'net04 \' | awk -F"|" {\'print $2\'} | awk \'{ gsub (" ", "", $0); print}\'` >> controller_log.log &&'
                                     'nova boot --image mcv --flavor m1.large --nic net-id=$network_id mcv_vm >> controller_log.log &&'
                                     'instance_ip=`nova floating-ip-create | grep \'net04\' | awk -F"|" {\'print $3\'} | awk \'{ gsub (" ", "", $0); print}\'` >> controller_log.log && echo $instance_ip &&'
                                     'nova floating-ip-associate mcv_vm $instance_ip >> controller_log.log &&'
                                     'nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0 >> controller_log.log &&'
                                     'nova secgroup-add-rule default tcp 22 22 0.0.0.0/0 >> controller_log.log' % (getting_image_command, ControllerImagePath)
                                    )
    instance_ip=www.readlines()[0]
    ssh.close()

    time.sleep(1200)
    instance_ip=instance_ip[0:-1]

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(instance_ip, username='mcv', password='mcv', key_filename='/tmp/id_rsa')
    qqq, www, eee = ssh.exec_command('sudo sed -i "/\[basic\]/acontroller_ip=%s" /etc/mcv/mcv.conf &&'
                                     'sudo sed -i "/\[basic\]/ainstance_ip=%s" /etc/mcv/mcv.conf &&'
                                     'sudo sed -i "/\[basic\]/aos_username=%s" /etc/mcv/mcv.conf &&'
                                     'sudo sed -i "/\[basic\]/aos_tenant_name=%s" /etc/mcv/mcv.conf &&'
                                     'sudo sed -i "/\[basic\]/aos_password=%s" /etc/mcv/mcv.conf &&'
                                     'sudo sed -i "/\[basic\]/aauth_endpoint_ip=%s" /etc/mcv/mcv.conf &&'
                                     'sudo sed -i "/\[basic\]/anailgun_host=%s" /etc/mcv/mcv.conf &&'
                                     'sudo sed -i "/\[basic\]/acluster_id=%s" /etc/mcv/mcv.conf &&'
                                     'sudo sed -i "s/version=6.1/version=%s/" /etc/mcv/mcv.conf &&'
                                     'sudo mcvconsoler --run custom resources >> mcv_cli_output.log &&'
                                     'sudo mcvconsoler --run custom default >> mcv_cli_output.log' % (str(CONF.basic.controller_ip), instance_ip, str(CONF.basic.os_username), str(CONF.basic.os_tenant_name), str(CONF.basic.os_password), str(CONF.basic.auth_endpoint_ip), str(CONF.basic.nailgun_host), str(CONF.basic.cluster_id), str(CONF.basic.version)))
    print (www.readlines())
    ssh.close()

