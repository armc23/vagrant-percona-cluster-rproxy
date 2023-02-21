# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure("2") do |config|
  
  config.vm.provider "virtualbox" do |v|
    v.memory = 2048
    v.cpus = 1
    v.linked_clone = true
  end

  (1..3).each do |i|
    config.vm.define "node#{i}" do |node|
      node.vm.box = "bento/ubuntu-18.04"
      node.vm.box_check_update = false
      node.vm.hostname = "node#{i}"
      node.vm.network "public_network",ip: "192.168.10.5#{i}"
      node.disksize.size = '20GB'
      node.vm.provision "shell", path: "./node#{i}/script.sh"
    end
  end

  
end
