Vagrant.configure(2) do |config|
  config.vm.box = "windows-2016-amd64"
  config.vm.provider "virtualbox" do |vb|
    vb.linked_clone = true
    vb.memory = 2048
    vb.cpus = 2
  end
  config.vm.provision "shell", inline: "Uninstall-WindowsFeature Windows-Defender-Features" # because defender slows things down a lot.
  config.vm.provision "reload"
  config.vm.provision "windows-update"
  config.vm.provision "shell", path: "windows-update-history.ps1"
end
