#!/bin/bash
# Helper script to repetitively test things quickly
yum -y install yum-plugin-priorities

curl https://dmsimard.com/rdo-mitaka-deps.repo |tee /etc/yum.repos.d/delorean-deps.repo
curl https://dmsimard.com/rdo-mitaka-release.repo |tee /etc/yum.repos.d/delorean.repo
yum -y install puppet rubygems git
gem install r10k
pushd /etc/puppet
PUPPETFILE=/root/centos-cloud/puppet/Puppetfile r10k puppetfile install -v
mv /root/centos-cloud/puppet/modules/centos_cloud modules/
echo "127.0.0.1 controller.openstack.ci.centos.org" >>/etc/hosts
puppet apply -e "include ::centos_cloud::controller" && puppet apply -e "include ::centos_cloud::compute" || exit 1
popd

echo "Done installing, provisioning test resources"
pushd /root
source openrc
ssh-keygen -f .ssh/id_rsa -t rsa -N ''
openstack keypair create --public-key .ssh/id_rsa.pub centos-cloud-key
wget -q http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2 -O /tmp/centos7.qcow2
virt-sysprep --enable=ssh-hostkeys,udev-persistent-net,net-hwaddr,dhcp-client-state,dhcp-server-state,customize \
             --edit '/etc/sysconfig/network-scripts/ifcfg-eth0:s/^BOOTPROTO=.*/BOOTPROTO=none/g' \
             --edit '/etc/sysconfig/network-scripts/ifcfg-eth0:s/^PERSISTENT_DHCLIENT=.*/PERSISTENT_DHCLIENT=0/g' \
             --write '/etc/cloud/cloud.cfg.d/00_disable_ec2_metadata.cfg:disable_ec2_metadata: True' \
             --write '/etc/cloud/cloud.cfg.d/99_manage_etc_hosts.cfg:manage_etc_hosts: True' \
             --root-password password:root \
             -a /tmp/centos7.qcow2
openstack image create --disk-format qcow2 --file /tmp/centos7.qcow2 centos7
neutron net-create testnet --shared --provider:network_type flat --provider:physical_network physnet0
neutron subnet-create testnet 172.19.0.0/22 --allocation_pool start=172.19.1.32,end=172.19.1.38 --disable-dhcp --gateway 172.19.3.254 --dns-nameserver 172.19.0.12
net_id=$(openstack network list -f value |awk '{print $1}')
openstack server create --flavor m1.small --image centos7 --nic net-id=${net_id} --key-name centos-cloud-key test-server
popd
