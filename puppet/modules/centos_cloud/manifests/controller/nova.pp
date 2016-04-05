class centos_cloud::controller::nova (
  $allowed_hosts = "172.19.0.0/22",
  $bind_host     = '127.0.0.1',
  $controller    = 'controller.openstack.ci.centos.org',
  $password      = 'nova',
  $password_api  = 'nova_api',
  $rabbit_port   = '5672',
  $user          = 'nova',
  $user_api      = 'nova_api'
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

  class { '::nova::db::mysql':
    allowed_hosts => [$controller, $allowed_hosts],
    host          => $bind_host,
    password      => $password,
    user          => $user
  }

  class { '::nova::db::mysql_api':
    host     => $database_host,
    password => $password_api,
    user     => $user_api
  }

  class { '::nova::keystone::auth':
    admin_url       => "http://${controller}:8774/v2/%(tenant_id)s",
    internal_url    => "http://${controller}:8774/v2/%(tenant_id)s",
    public_url      => "http://${controller}:8774/v2/%(tenant_id)s",
    admin_url_v3    => "http://${controller}:8774/v3",
    internal_url_v3 => "http://${controller}:8774/v3",
    public_url_v3   => "http://${controller}:8774/v3",
    password        => $password
  }

  class { '::nova':
    api_database_connection => "mysql+pymysql://${user_api}:${password_api}@${controller}/nova_api?charset=utf8",
    database_connection     => "mysql+pymysql://${user}:${password}@${controller}/nova?charset=utf8",
    glance_api_servers      => "http://${controller}:9292",
    notification_driver     => 'messagingv2',
    notify_on_state_change  => 'vm_and_task_state',
    rabbit_host             => $controller,
    rabbit_password         => $password,
    rabbit_port             => $rabbit_port,
    rabbit_userid           => $user,
    rabbit_use_ssl          => false
  }

  class { '::nova::api':
    admin_password   => $password,
    api_bind_address => $bind_host,
    auth_uri         => "http://${controller}:5000",
    enabled_apis     => ['osapi_compute'],
    identity_uri     => "http://${controller}:35357",
    osapi_v3         => true,
    service_name     => 'httpd',
    sync_db_api      => true
  }

  include ::apache
  class { '::nova::wsgi::apache':
    bind_host => $bind_host,
    ssl       => false,
    workers   => $::processorcount
  }

  include ::nova::client
  include ::nova::conductor
  include ::nova::consoleauth
  include ::nova::cron::archive_deleted_rows
  include ::nova::scheduler
  include ::nova::scheduler::filter
  include ::nova::vncproxy

}
