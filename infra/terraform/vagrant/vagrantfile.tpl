require 'json'
vms = JSON.parse('${vms_json}')

Vagrant.configure("2") do |config|
  vms.each do |vm| 
    config.vm.define vm["name"] do |vm_config|
      vm_config.vm.box = "ubuntu/jammy64" 
      vm_config.vm.hostname = vm["name"] 
      vm_config.vm.network "private_network", ip: vm["ip"] 
      vm_config.ssh.connect_timeout = 300
      vm_config.vm.boot_timeout = 600  
      vm_config.vm.provider "virtualbox" do |vb|
        vb.memory = vm["memory"]
        vb.cpus = 1
        vb.gui = false 
      end
      vm_config.vm.provision "shell" , path: vm["path"]
    end
  end 
end
