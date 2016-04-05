class centos_cloud::compute {
  include centos_cloud::server
  include centos_cloud::compute::nova

  file { '/etc/modprobe.d/kvm_intel.conf':
    content => "options kvm_intel nested=1\n",
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
  }
}
