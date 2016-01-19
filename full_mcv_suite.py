from __future__ import print_function
from oslo.config import cfg
import paramiko
import time
opt_group = cfg.OptGroup(name='basic',
                         title='mcvbv.conf')
simple_opts = [
    cfg.StrOpt('controller_ip', default=False,
                help=('True enables, False disables')),
    cfg.StrOpt('instance_ip', default=False,
                help=('True enables, False disables')),
    cfg.StrOpt('os_username', default=False,
                help=('True enables, False disables')),
    cfg.StrOpt('os_tenant_name', default=False,
                help=('True enables, False disables')),
    cfg.StrOpt('os_password', default=False,
                help=('True enables, False disables')),
    cfg.StrOpt('auth_endpoint_ip', default=False,
                help=('True enables, False disables')),
    cfg.StrOpt('nailgun_host', default=False,
                help=('True enables, False disables')),
    cfg.StrOpt('cluster_id', default=False,
                help=('True enables, False disables')),
    cfg.StrOpt('version', default=False,
                help=('True enables, False disables')),
    cfg.StrOpt('private_endpoint_ip', default=False,
                help=('True enables, False disables')),
    cfg.StrOpt('image_url', default=False,
                help=('True enables, False disables')),
    cfg.StrOpt('ssh_key_loc', default=False,
                help=('True enables, False disables'))

    # need add checks for instance_ip
]

CONF = cfg.CONF
CONF.register_group(opt_group)
CONF.register_opts(simple_opts, opt_group)

if __name__ == "__main__":
    CONF(default_config_files=['mcvbv.conf'])
    #CONF.basic.controller_ip)
    print(CONF.basic.instance_ip)
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

# work with controller
#    ssh = paramiko.SSHClient()
#    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
#    ssh.connect(CONF.basic.controller_ip, username='root', password='r00tme', key_filename='/tmp/id_rsa')
#    qqq, www, eee = ssh.exec_command(
#                            #        'wget %s &&'
#                                     '. openrc >> controller_log.log &&'
#                                     'sudo apt-get install sshpass >> controller_log.log &&'
#                                     'sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config >> controller_log.log &&'
#                                     'service ssh restart >> controller_setups.log &&'
#                                     'glance image-create --name mcv --disk-format qcow2 --container-format bare --is-public true --file %s --progress >> controller_log.log &&'
#                                     'network_id=`neutron net-list | grep \'net04 \' | awk -F"|" {\'print $2\'} | awk \'{ gsub (" ", "", $0); print}\'` >> controller_log.log &&'
#                                     'nova boot --image mcv --flavor m1.large --nic net-id=$network_id mcv_vm >> controller_log.log &&'
#                                     'instance_ip=`nova floating-ip-create | grep \'net04\' | awk -F"|" {\'print $3\'} | awk \'{ gsub (" ", "", $0); print}\'` >> controller_log.log &&'
#                                     'nova floating-ip-associate mcv_vm $instance_ip >> controller_log.log &&'
#                                     'nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0 >> controller_log.log &&'
#                                     'nova secgroup-add-rule default tcp 22 22 0.0.0.0/0 >> controller_log.log' % ('mcv-0.5.0-build.105-2016-01-19-11-53-40.qcow2'))
#    print (www.readlines())
#    ssh.close()
#    time.sleep(1200)


    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(CONF.basic.instance_ip, username='mcv', password='mcv', key_filename='/tmp/id_rsa')
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
                                     'sudo mcvconsoler --run custom default >> mcv_cli_output.log' % (str(CONF.basic.controller_ip), str(CONF.basic.instance_ip), str(CONF.basic.os_username), str(CONF.basic.os_tenant_name), str(CONF.basic.os_password), str(CONF.basic.auth_endpoint_ip), str(CONF.basic.nailgun_host), str(CONF.basic.cluster_id), str(CONF.basic.version)))
    print (www.readlines())
    ssh.close()

