$:.unshift File.expand_path("../lib", __FILE__)

require "vagrant-windows-update/version"

Gem::Specification.new do |gem|
  gem.name          = "vagrant-windows-update"
  gem.version       = VagrantPlugins::WindowsUpdate::VERSION
  gem.platform      = Gem::Platform::RUBY
  gem.license       = "LGPLv3"
  gem.authors       = "Rui Lopes"
  gem.email         = "rgl@ruilopes.com"
  gem.homepage      = "https://github.com/rgl/vagrant-windows-update"
  gem.description   = "Vagrant plugin for installing Windows updates."
  gem.summary       = "Vagrant plugin for installing Windows updates."
  gem.files         = Dir.glob("lib/**/*").reject {|p| File.directory? p}
  gem.require_path  = "lib"

  gem.add_development_dependency "rake"
end
