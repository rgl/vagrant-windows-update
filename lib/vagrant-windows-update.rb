begin
  require "vagrant"
rescue LoadError
  raise "The Vagrant Windows Update plugin must be run within Vagrant."
end

if Vagrant::VERSION < "1.9.0"
  raise "The Vagrant Windows Update plugin is only compatible with Vagrant 1.9+"
end

module VagrantPlugins
  module WindowsUpdate
    class Plugin < Vagrant.plugin("2")
      name "Windows Update"
      description "Vagrant plugin to update a Windows VM as a provisioning step."

      provisioner "windows-update" do
        class Provisioner < Vagrant.plugin("2", :provisioner)
          def initialize(machine, config)
            super
          end

          def configure(root_config)
          end

          # see https://github.com/mitchellh/vagrant/blob/master/lib/vagrant/ui.rb
          # see https://github.com/mitchellh/vagrant/blob/master/lib/vagrant/plugin/v2/provisioner.rb
          # see https://github.com/mitchellh/vagrant/blob/master/lib/vagrant/plugin/v2/communicator.rb
          # see https://github.com/mitchellh/vagrant/blob/master/plugins/provisioners/shell/provisioner.rb
          def provision
            remote_path = "C:/Windows/Temp/vagrant-windows-update.ps1"
            @machine.communicate.upload(
              File.join(File.dirname(__FILE__), "vagrant-windows-update", "windows-update.ps1"),
              remote_path)
            command = "PowerShell -ExecutionPolicy Bypass -OutputFormat Text -File #{remote_path}"
            loop do
              begin
                until @machine.communicate.ready?
                  sleep 10
                end

                reboot_required = false
                @machine.communicate.sudo(command, {elevated: true, interactive: false}) do |type, data|
                  reboot_required = true if type == :stdout && data.start_with?("Rebooting...")
                  handle_comm(type, data)
                end
                break unless reboot_required

                # NB we have to set an absurd high halt timeout to make sure the machine is
                #    not turned off before the Windows updates are installed.
                original_graceful_halt_timeout = @machine.config.vm.graceful_halt_timeout
                @machine.config.vm.graceful_halt_timeout = 4*60*60 # 4h.
                begin
                  options = {}
                  options[:provision_ignore_sentinel] = false
                  @machine.action(:reload, options)
                ensure
                  @machine.config.vm.graceful_halt_timeout = original_graceful_halt_timeout
                end
              rescue => e
                @machine.ui.warn("Ignoring error, hoping it is transient: #{e.class} #{e} at:\n\t#{e.backtrace.join("\n\t")}")
                next
              end
            end
          end

          def cleanup
          end

          protected

          # This handles outputting the communication data back to the UI
          def handle_comm(type, data)
            if [:stderr, :stdout].include?(type)
              # Output the data with the proper color based on the stream.
              color = type == :stdout ? :green : :red

              # Clear out the newline since we add one
              data = data.chomp
              return if data.empty?

              options = {}
              options[:color] = color if !config.keep_color

              @machine.ui.info(data.chomp, options)
            end
          end
        end

        Provisioner
      end
    end
  end
end
