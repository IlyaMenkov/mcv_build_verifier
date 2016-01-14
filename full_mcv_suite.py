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
]

CONF = cfg.CONF
CONF.register_group(opt_group)
CONF.register_opts(simple_opts, opt_group)

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(CONF.basic.controller_ip, username='root', password='r00tme', key_filename='/tmp/id_rsa')
ssin, ssout, sserr = ssh.exec_command('echo CONF.basic.instance_ip >> logfile.log')
#print ssout.readlines()
ssh.close()

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(CONF.basic.instance_ip, username='mcv', password='mcv', key_filename='/tmp/id_rsa')
hjkin, qqq, hjgjlk = ssh.exec_command('sudo mcvconsoler --run custom resources')
#print qqq.readlines()
ssh.close()

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
