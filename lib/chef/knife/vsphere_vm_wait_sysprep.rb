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
         :description => "The time in seconds to wait between queries for CustomizationSucceeded event. Default: 60 seconds",
         :default => 60

  option :timeout,
         :long => "--timeout TIME",
         :description => "The timeout in seconds before aborting. Default: 300 seconds",
         :default => 300

  def run
    $stdout.sync = true

    vmname = @name_args[0]
    if vmname.nil?
      show_usage
      fatal_exit("You must specify a virtual machine name")
    end

    config[:vmname] = vmname

    sleep_time = get_config(:sleep).to_i
    sleep_timeout = get_config(:timeout).to_i

    vim = get_vim_connection
    vem = vim.serviceContent.eventManager

    dc = get_datacenter

    folder = find_folder(get_config(:folder)) || dc.vmFolder
    vm = find_in_folder(folder, RbVmomi::VIM::VirtualMachine, vmname) or abort "VM could not be found in #{folder}"

    wait_for_sysprep = true
    waited_seconds = 0

    print 'Waiting for sysprep...'
    while wait_for_sysprep do
      events = query_customization_succeeded(vm, vem)

      if events.size > 0
        events.each do |e|
          puts "\n#{e.fullFormattedMessage}"
        end
        wait_for_sysprep = false
      elsif waited_seconds >= sleep_timeout
        abort "\nCustomization of VM #{vmname} not succeeded within #{sleep_timeout} seconds."
      else
        print '.'
        sleep(sleep_time)
        waited_seconds += sleep_time
      end
    end
  end

  def query_customization_succeeded(vm, vem)
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
