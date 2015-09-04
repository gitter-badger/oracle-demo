#
# This is a demo manifest to install an Oracle dababase
#
$oracle_base  = '/opt/oracle'
$oracle_home  = '/opt/oracle/app/11.04'
$groups       = ['oinstall', 'dba']
$full_version = '11.2.0.4'
$version      = '11.2'
$dbname       = 'demo'
$domain_name  = 'example.com'

contain oracle_os_settings
contain database

Class['oracle_os_settings'] -> Class['Database']

class oracle_os_settings
{

  exec { "create swap file":
    command => "/bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=8192",
    creates => "/var/swap.1",
  }

  exec { "attach swap file":
    command => "/sbin/mkswap /var/swap.1 && /sbin/swapon /var/swap.1",
    require => Exec["create swap file"],
    unless => "/sbin/swapon -s | grep /var/swap.1",
  }

  #add swap file entry to fstab
  exec {"add swapfile entry to fstab":
    command => "/bin/echo >>/etc/fstab /var/swap.1 swap swap defaults 0 0",
    require => Exec["attach swap file"],
    user => root,
    unless => "/bin/grep '^/var/swap.1' /etc/fstab 2>/dev/null",
  }


  mount { '/dev/shm':
    ensure      => present,
    atboot      => true,
    device      => 'tmpfs',
    fstype      => 'tmpfs',
    options     => 'size=3500m',
  }

  service { iptables:
      enable    => false,
      ensure    => false,
      hasstatus => true,
  }

  $groups = ['oinstall','dba' ,'oper' ]

  group { $groups :
    ensure      => present,
  }

  user { 'oracle' :
    ensure      => present,
    uid         => 600,
    gid         => 'oinstall',  
    groups      => $groups,
    shell       => '/bin/bash',
    password    => '$1$DSJ51vh6$4XzzwyIOk6Bi/54kglGk3.',
    home        => "/home/oracle",
    comment     => "This user oracle was created by Puppet",
    require     => Group[$groups],
    managehome  => true,
  }

  $packages = [ 'binutils.x86_64', 'compat-libstdc++-33.x86_64', 'glibc.x86_64','ksh.x86_64','libaio.x86_64',
               'libgcc.x86_64', 'libstdc++.x86_64', 'make.x86_64', 'gcc.x86_64',
               'gcc-c++.x86_64','glibc-devel.x86_64','libaio-devel.x86_64','libstdc++-devel.x86_64',
               'sysstat.x86_64','unixODBC-devel','glibc.i686', 'unzip']
         

  package { $packages:
    ensure  => present,
  }

  class { 'limits':
     config => {
                '*'       => { 'nofile'  => { soft => '2048'   , hard => '8192',   },},
                'oracle'  => { 'nofile'  => { soft => '65536'  , hard => '65536',  },
                                'nproc'  => { soft => '2048'   , hard => '16384',  },
                                'stack'  => { soft => '10240'  ,},},
                },
     use_hiera => false,
  }
  sysctl { 'kernel.msgmnb':                 ensure => 'present', permanent => 'yes', value => '65536',}
  sysctl { 'kernel.msgmax':                 ensure => 'present', permanent => 'yes', value => '65536',}
  sysctl { 'kernel.shmmax':                 ensure => 'present', permanent => 'yes', value => '2588483584',}
  sysctl { 'kernel.shmall':                 ensure => 'present', permanent => 'yes', value => '2097152',}
  sysctl { 'fs.file-max':                   ensure => 'present', permanent => 'yes', value => '6815744',}
  sysctl { 'net.ipv4.tcp_keepalive_time':   ensure => 'present', permanent => 'yes', value => '1800',}
  sysctl { 'net.ipv4.tcp_keepalive_intvl':  ensure => 'present', permanent => 'yes', value => '30',}
  sysctl { 'net.ipv4.tcp_keepalive_probes': ensure => 'present', permanent => 'yes', value => '5',}
  sysctl { 'net.ipv4.tcp_fin_timeout':      ensure => 'present', permanent => 'yes', value => '30',}
  sysctl { 'kernel.shmmni':                 ensure => 'present', permanent => 'yes', value => '4096', }
  sysctl { 'fs.aio-max-nr':                 ensure => 'present', permanent => 'yes', value => '1048576',}
  sysctl { 'kernel.sem':                    ensure => 'present', permanent => 'yes', value => '250 32000 100 128',}
  sysctl { 'net.ipv4.ip_local_port_range':  ensure => 'present', permanent => 'yes', value => '9000 65500',}
  sysctl { 'net.core.rmem_default':         ensure => 'present', permanent => 'yes', value => '262144',}
  sysctl { 'net.core.rmem_max':             ensure => 'present', permanent => 'yes', value => '4194304', }
  sysctl { 'net.core.wmem_default':         ensure => 'present', permanent => 'yes', value => '262144',}
  sysctl { 'net.core.wmem_max':             ensure => 'present', permanent => 'yes', value => '1048576',}

}

class database{
  ora_install::installdb{ '112040_Linux-x86-64':
    version                   => $full_version,
    file                      => 'p13390677_112040_Linux-x86-64',
    database_type             => 'EE',
    oracle_base               => $oracle_base,
    oracle_home               => $oracle_home,
    puppet_download_mnt_point => '/vagrant',
    remote_file               => false,
  }->

  file{'/tmp': ensure => 'directory'} ->

  ora_install::net{ 'config net8':
    oracle_home  => $oracle_home,
    version      => $version,
    download_dir => '/tmp',
    require      => Ora_install::Installdb['112040_Linux-x86-64'],
  }

  ora_install::listener{'start listener':
    oracle_base  => $oracle_base,
    oracle_home  => $oracle_home,
    action       => 'start',
    require      => Ora_install::Net['config net8'],
  }

  ora_database{$dbname:
    ensure            => present,
    oracle_base       => $oracle_base,
    oracle_home       => $oracle_home,
    control_file      => 'reuse',
    extent_management => 'local',
    logfile_groups => [
        {file_name => 'demo1.log', size => '50M', reuse => true},
        {file_name => 'demo2.log', size => '50M', reuse => true},
      ],
    default_tablespace => {
      name      => 'USERS',
      datafile  => {
        file_name  => 'users.dbs',
        size       => '50M',
        reuse      =>  true,
      },
      extent_management => {
        'type'        => 'local',
        autoallocate  => true,
      }
    },
    datafiles       => [
      {file_name   => 'demo1.dbs', size => '100M', reuse => true},
      {file_name   => 'demo2.dbs', size => '100M', reuse => true},
    ],
    default_temporary_tablespace => {
      name      => 'TEMP',
      'type'    => 'bigfile',
      tempfile  => {
        file_name  => 'tmp.dbs',
        size       => '50M',
        reuse      =>  true,
        autoextend => {
          next    => '10M',
          maxsize => 'unlimited',
        }
      },
      extent_management => {
        'type'        => 'local',
        uniform_size  => '10M',
      },
    },
    undo_tablespace   => {
      name      => 'UNDOTBS',
      'type'    => 'bigfile',
      datafile  => {
        file_name  => 'undo.dbs',
        size       => '50M',
        reuse      =>  true,
      }
    },
    timezone       => '+05:00',
    sysaux_datafiles => [
      {file_name   => 'sysaux1.dbs', size => '50M', reuse => true},
      {file_name   => 'sysaux2.dbs', size => '50M', reuse => true},
    ],
    require        => Ora_install::Listener['start listener'],
  } ->

  ora_install::dbactions{ "start_${dbname}":
    oracle_home => $oracle_home,
    db_name     => $dbname,
  } ->

  ora_install::autostartdatabase{ 'autostart oracle':
    oracle_home => $oracle_home,
    db_name     => $dbname,
  } ->

  ora_tablespace {'DEMO':
    ensure                   => present,
    size                     => '20M',
    logging                  => yes,
    autoextend               => on,
    next                     => '10M',
    max_size                 => '30M',
    extent_management        => local,
    segment_space_management => auto,
  } ->

  ora_user{'DEMO':
    ensure     => present,
    password   => 'DEMO',
    quotas     => {
      'SYSTEM' => 0,
      'DEMO'   => 'unlimited',
    },
    grants    => [
      'CONNECT'
    , 'CREATE TABLE'
    , 'CREATE TRIGGER'
    , 'CREATE TYPE'
    , 'CREATE VIEW'
    , 'CREATE SEQUENCE'
    , 'QUERY REWRITE'
    , 'CREATE PROCEDURE'
    , 'SELECT_CATALOG_ROLE'
    ],
  } 

  ora_service{'DEMODB.demo.com':
    require => Ora_database['demo'],
  }



}
