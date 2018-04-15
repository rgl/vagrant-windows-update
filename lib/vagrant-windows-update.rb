begin
  require "vagrant"
rescue LoadError
  raise "The Vagrant Windows Update plugin must be run within Vagrant."
end

if Vagrant::VERSION < "2.0.3"
  raise "The Vagrant Windows Update plugin is only compatible with Vagrant 2.0.3+"
end

require "base64"

module VagrantPlugins
  module WindowsUpdate
    class Plugin < Vagrant.plugin("2")
      name "Windows Update"
      description "Vagrant plugin to update a Windows VM as a provisioning step."

      config("windows-update", :provisioner) do
        class Config < Vagrant.plugin("2", :config)
          attr_accessor :filters
          attr_accessor :keep_color

          def initialize
            @filters = UNSET_VALUE
            @keep_color = UNSET_VALUE
          end

          def finalize!
            @filters = ['include:$_.AutoSelectOnWebSites'] if @filters == UNSET_VALUE
            @keep_color = false if @keep_color == UNSET_VALUE
          end

          def validate(machine)
            errors = _detected_errors
            errors << 'filters must be a string array' unless filters_valid?
            return { "windows-update provisioner" => errors }
          end

          def filters_valid?
            return false if !filters.is_a?(Array)
            filters.each do |a|
              return false if !a.kind_of?(String)
            end
            return true
          end
        end

        Config
      end

      provisioner("windows-update") do
        class Provisioner < Vagrant.plugin("2", :provisioner)
          # see https://github.com/mitchellh/vagrant/blob/master/lib/vagrant/ui.rb
          # see https://github.com/mitchellh/vagrant/blob/master/lib/vagrant/plugin/v2/provisioner.rb
          # see https://github.com/mitchellh/vagrant/blob/master/lib/vagrant/plugin/v2/communicator.rb
          # see https://github.com/mitchellh/vagrant/blob/master/plugins/provisioners/shell/provisioner.rb
          def provision
            remote_path = "C:/Windows/Temp/vagrant-windows-update.ps1"
            @machine.communicate.upload(
              File.join(File.dirname(__FILE__), "vagrant-windows-update", "windows-update.ps1"),
              remote_path)
            command = "PowerShell -ExecutionPolicy Bypass -OutputFormat Text -EncodedCommand #{windows_update_encoded_command(remote_path, config.filters)}"
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

          def windows_update_encoded_command(remote_path, filters)
            # NB you can get the string back with:
            #     Base64.decode64(encoded).force_encoding("utf-16le")
            return Base64.strict_encode64("#{remote_path}#{windows_update_filters_argument(filters)}".encode("utf-16le"))
          end

          def windows_update_filters_argument(filters)
            return "" if !filters
            arg = " -Filters "
            filters.each_with_index do |filter, i|
              arg += "," if i > 0
              arg += "'#{filter.gsub("'", "''")}'" # escape single quotes with another single quote.
            end
            return arg
          end
        end

        Provisioner
      end
    end
  end
end
