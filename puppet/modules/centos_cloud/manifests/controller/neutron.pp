class centos_cloud::controller::neutron (
  $allowed_hosts = "172.19.0.0/22",
  $controller    = 'controller.openstack.ci.centos.org',
  $bind_host     = '127.0.0.1',
  $rabbit_port   = '5672',
  $user          = 'neutron',
  $password      = 'neutron',
  $nova_password = 'nova'
) {

  rabbitmq_user { $user:
    admin    => true,
    password => $password,
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq']
  }

  rabbitmq_user_permissions { "${user}@/":
    configure_permission => '.*',
    read_permission      => '.*',
    write_permission     => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq']
  }

  class { '::neutron::db::mysql':
    allowed_hosts => [$controller, $allowed_hosts],
    host          => $bind_host,
    password      => $password,
    user          => $user
  }

  class { '::neutron::keystone::auth':
    admin_url    => "http://${controller}:9696",
    internal_url => "http://${controller}:9696",
    public_url   => "http://${controller}:9696",
    password     => $password
  }

  class { '::neutron':
    allow_overlapping_ips   => false,
    core_plugin             => 'ml2',
    dhcp_agent_notification => false,
    rabbit_user             => $user,
    rabbit_password         => $password,
    rabbit_host             => $controller,
    rabbit_port             => $rabbit_port
  }

  include ::neutron::client

  class { '::neutron::server':
    api_workers         => $::processorcount,
    auth_uri            => "http://${controller}:5000",
    auth_url            => "http://${controller}:35357",
    database_connection => "mysql+pymysql://${user}:${password}@${controller}/neutron?charset=utf8",
    password            => $password,
    rpc_workers         => $::processorcount,
    sync_db             => true
  }

  class { '::neutron::plugins::ml2':
    enable_security_group => true,
    mechanism_drivers     => ['linuxbridge'],
    tenant_network_types  => ['vlan'],
    type_drivers          => ['flat', 'vlan'],
    network_vlan_ranges   => 'physnet0:1000:1999'
  }

  class { '::neutron::agents::ml2::linuxbridge':
    firewall_driver             => 'neutron.agent.firewall.NoopFirewallDriver',
    local_ip                    => $::ipaddress,
    physical_interface_mappings => ['physnet0:eth0'],
    tunnel_types                => ['vlan']
  }

  class { '::neutron::server::notifications':
    auth_url => "http://${controller}:35357",
    nova_url => "http://${controller}:8774/v2",
    password => $nova_password
  }
}
