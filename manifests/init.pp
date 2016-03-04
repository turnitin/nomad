# == Class: nomad
#
# Full description of class nomadproject here.
#
# === Parameters
#
# Document parameters here.
#
# [*version*]
#   Version of nomad to install defaults to 0.3.0
#
# [*user*]
#   Run user defaults to root
#
# [*group*]
#   Run group defaults to root
#
# [*data_dir*]
#   Where to store the nomad data defaults to /opt/nomad
#
# [*bin_dir*]
#   Where to install the nomad binary
#
# [*bind_interface*]
#   bind to a specific interface
#
# === Authors
#
# Chris Mague <github@mague.com>
# Jason Temple <jtemple@turnitin.com>
#
# === Copyright
#
# Copyright 2015 Your name here, unless otherwise noted.
#
class nomad (
  $user             = 'nomad',
  $group            = 'nomad',
  $version          = '0.3.0',
  $port             = '4647',
  $bin_dir          = '/usr/sbin',
  $data_dir         = '/var/nomad',
  $nomad_role       = '',
  $datacenter       = 'devstk',
  $region           = '',
  $bind_interface   = '',
  $bootstrap_expect = 1,
  $server_list      = [],
  $config_hash      = {},
  ){

  $config_default = {
    'data_dir'   => $data_dir,
    'region'     => $region,
    'datacenter' => $datacenter,
    'name'       => $::hostname,
    'bind_addr'  => $::ipaddress,
  }

  if $::hostname =~ /^nomad(\d+)\./ {
    $nomad_role = 'server'
  }
  else {
    $nomad_role = 'client'
  }

  if ($nomad_role == 'client') and ( size($server_list) == 0 ) {
    notify { "WARNING: Set as ${nomad_role}, but no servers set => ${server_list}": }
  }
    
  validate_hash($config_hash)
  $final_sets = merge($config_default, $config_hash)

  $os = downcase($::kernel)
  $download_url = "https://releases.hashicorp.com/nomad/${version}/nomad_${version}_${os}_${::architecture}.zip"

  file { $data_dir:
    ensure => 'directory',
    owner  => $user,
    group  => $group,
    mode   => '0755',
  }

  group { $group:
    ensure => 'present',
  }

  user { $user:
    ensure   => 'present',
    password => '!!',
    groups   => [$group, nomad],
  }

  staging::file { 'nomad.zip':
    source => $download_url
  } ->
  staging::extract { 'nomad.zip':
    target  => $bin_dir,
    creates => "${bin_dir}/nomad",
  } ->
  file { "${bin_dir}/nomad":
    owner => 'root',
    group => 0,
    mode  => '0555',
  }

  file { '/etc/nomad.d':
    ensure => 'directory',
    owner  => '$user',
    group  => '$group',
    mode   => '0755',
  }

  file { '/etc/nomad.d/config.hcl':
    ensure  => present,
    owner   => $user,
    group   => $group,
    mode    => '0644',
    content => template('nomad/nomad.erb'),
    require => File["${bin_dir}/nomad"],
    notify  => Service['nomad'],
  }

  file { '/usr/lib/systemd/system/nomad.service':
    ensure  => present,
    owner   => root,
    group   => root,
    mode    => '0644',
    content => template('nomad/nomad.service.erb'),
  }

  service { 'nomad' :
    ensure  => running,
    enable  => true,
    require => File['/etc/nomad.d/config.hcl', '/usr/lib/systemd/system/nomad.service'],
  }

}
