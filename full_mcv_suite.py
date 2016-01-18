from __future__ import print_function
from oslo.config import cfg
import paramiko

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
    print(CONF.basic.controller_ip)
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
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(CONF.basic.controller_ip, username='root', password='r00tme', key_filename='/tmp/id_rsa')
    qqq, www, eee = ssh.exec_command('wget %s &&'
                                     '. openrc'
                                     'sudo apt-get install sshpass'
                                     'sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config'
                                     'service ssh restart'
                                     'glance image-create --name mcv --disk-format qcow2 --container-format bare --is-public true --file %s --progress'
                                     'network_id=`neutron net-list | grep \'net04 \' | awk -F"|" {\'print $2\'} | awk \'{ gsub (" ", "", $0); print}\'`'
                                     'nova boot --image mcv --flavor m1.large --nic net-id=$network_id mcv_vm'
                                     'instance_ip=`nova floating-ip-create | grep \'net04\' | awk -F"|" {\'print $3\'} | awk \'{ gsub (" ", "", $0); print}\'`'
                                     'nova floating-ip-associate mcv_vm %s'
                                     'nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0'
                                     'nova secgroup-add-rule default tcp 22 22 0.0.0.0/0' % (str(CONF.basic.image_url), image_name, str(CONF.basic.instance_ip)))
    print (www.readlines())
    ssh.close()

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(CONF.basic.instance_ip, username='mcv', password='mcv', key_filename='/tmp/id_rsa')
    qqq, www, eee = ssh.exec_command('sudo mcvconsoler --run custom resources')
    print (www.readlines())
    ssh.close()

