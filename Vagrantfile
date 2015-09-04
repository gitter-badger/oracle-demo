# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "puppetlabs/centos-6.6-64-puppet"
  config.vm.box_check_update = false
  config.vm.provision "shell", inline: "/opt/puppetlabs/puppet/bin/gem install librarian-puppet --no-rdoc --no-ri"
  config.vm.provision "shell", inline: "cd /vagrant; /opt/puppetlabs/puppet/bin/librarian-puppet install"
  config.vm.provision "shell", inline: "puppet apply /vagrant/manifests/default.pp --modulepath /vagrant/modules"
end
