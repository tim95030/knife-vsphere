#
# Author:: Ezra Pagel (<ezra@cpan.org>)
# Contributor:: Malte Heidenreich (https://github.com/mheidenr)
# License:: Apache License, Version 2.0
#

require 'chef/knife'
require 'chef/knife/base_vsphere_command'
require 'rbvmomi'

# Wait for vm finishing Sysprep.
# usage:
# knife vsphere vm wait sysprep somemachine --sleep 30 \
#     --timeout 600
class Chef::Knife::VsphereVmWaitSysprep < Chef::Knife::BaseVsphereCommand

  banner "knife vsphere vm wait sysprep VMNAME (options)"

  get_common_options

  option :sleep,
         :long => "--sleep TIME",
         :description => "The time in seconds to wait between queries for CustomizationSucceeded event. Default: 60 seconds"
  option :timeout,
         :long => "--timeout TIME",
         :description => "The timeout in seconds before aborting. Default: 300 seconds"

  def run
    $stdout.sync = true

    vmname = @name_args[0]
    if vmname.nil?
      show_usage
      fatal_exit("You must specify a virtual machine name")
    end

    config[:vmname] = vmname

    sleep_time = get_config(:sleep) ? get_config(:sleep).to_i : 60
    sleep_timeout = get_config(:timeout) ? get_config(:timeout).to_i : 300

    vim = get_vim_connection
    vem = vim.serviceContent.eventManager

    dc = get_datacenter

    folder = find_folder(get_config(:folder)) || dc.vmFolder
    vm = find_in_folder(folder, RbVmomi::VIM::VirtualMachine, vmname) or abort "VM could not be found in #{dest_folder}"

    wait_for_sysprep = true
    waited_seconds = 0

    while wait_for_sysprep do
      events = queryCustomizationSucceeded(vm, vem)

      if events.size > 0
        events.each do |e|
          puts e.fullFormattedMessage
        end
        wait_for_sysprep = false
      elsif waited_seconds >= sleep_timeout
        abort "Customization of VM #{vmname} not succeeded within #{sleep_timeout} seconds."
      else
        sleep(sleep_time)
        waited_seconds += sleep_time
      end
    end
  end

  def queryCustomizationSucceeded(vm, vem)
    vem.QueryEvents(
        :filter =>
            RbVmomi::VIM::EventFilterSpec(
                :entity =>
                    RbVmomi::VIM::EventFilterSpecByEntity(
                        :entity => vm,
                        :recursion => RbVmomi::VIM::EventFilterSpecRecursionOption(:self)
                    ),
                :eventTypeId => ['CustomizationSucceeded']
            )
    )
  end

end
