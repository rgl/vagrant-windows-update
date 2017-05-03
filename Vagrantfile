Vagrant.configure(2) do |config|
  config.vm.box = "windows-2016-amd64"
  config.vm.provider "virtualbox" do |vb|
    vb.linked_clone = true
    vb.memory = 2048
    vb.cpus = 2
  end
  config.vm.provision "windows-update"
  config.vm.provision "shell", path: "windows-update-history.ps1"
end
