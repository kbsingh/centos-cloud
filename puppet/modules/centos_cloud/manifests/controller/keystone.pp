class centos_cloud::controller::keystone (
  $allowed_hosts          = "172.19.0.0/22",
  $bind_host              = '127.0.0.1',
  $controller             = 'controller.openstack.ci.centos.org',
  $cache_enabled          = true,
  $cache_backend          = 'oslo_cache.memcache_pool',
  $cache_memcache_servers = ['127.0.0.1:11211'],
  $password               = 'keystone',
  $token_driver           = 'memcache',
  $token_caching          = true,
  $user                   = 'keystone'
) {

  include centos_cloud::controller::memcached

  include ::keystone::client
  include ::keystone::cron::token_flush

  class { '::keystone::db::mysql':
    allowed_hosts => [$controller, $allowed_hosts],
    host          => $bind_host,
    password      => $password,
    user          => $user
  }

  class { '::keystone':
    admin_bind_host        => $bind_host,
    admin_token            => $password,
    cache_enabled          => $cache_enabled,
    cache_backend          => $cache_backend,
    cache_memcache_servers => $cache_memcache_servers,
    database_connection    => "mysql+pymysql://${user}:${password}@${controller}/keystone",
    enabled                => true,
    public_bind_host       => $bind_host,
    service_name           => 'httpd',
    token_driver           => $token_driver,
    token_caching          => $token_caching
  }

  include ::apache
  class { '::keystone::wsgi::apache':
    admin_bind_host => $bind_host,
    bind_host       => $bind_host,
    ssl             => false,
    workers         => $::processorcount
  }

  class { '::keystone::roles::admin':
    email    => 'ci@centos.org',
    password => $password
  }

  class { '::keystone::endpoint':
    admin_url    => "http://${controller}:35357",
    internal_url => "http://${controller}:5000",
    public_url   => "http://${controller}:5000"
  }

  include ::keystone::disable_admin_token_auth

  class { '::openstack_extras::auth_file':
    auth_url       => "http://${controller}:5000/v3/",
    password       => $password,
    project_domain => 'default',
    user_domain    => 'default'
  }
}
