#
# Author:: Ezra Pagel (<ezra@cpan.org>)
# License:: Apache License, Version 2.0
#

require 'chef/knife'
require 'chef/knife/base_vsphere_command'
require 'rbvmomi'

# These two are needed for the '--purge' deletion case
require 'chef/node'
require 'chef/api_client'

# Delete a virtual machine from vCenter
class Chef::Knife::VsphereVmDelete < Chef::Knife::BaseVsphereCommand
  banner 'knife vsphere vm delete VMNAME'

  option :purge,
         short: '-P',
         long: '--purge',
         boolean: true,
         description: 'Destroy corresponding node and client on the Chef Server, in addition to destroying the VM itself.'

  option :chef_node_name,
         short: '-N NAME',
         long: '--node-name NAME',
         description: 'The Chef node name for your new node'

  common_options

  # Extracted from Chef::Knife.delete_object, because it has a
  # confirmation step built in... By specifying the '--purge'
  # flag (and also explicitly confirming the server destruction!)
  # the user is already making their intent known. It is not
  # necessary to make them confirm two more times.
  def destroy_item(itemClass, name, type_name)
    object = itemClass.load(name)
    object.destroy
    puts "Deleted #{type_name} #{name}"
  end

  def run
    $stdout.sync = true

    vmname = @name_args[0]

    if vmname.nil?
      show_usage
      fatal_exit('You must specify a virtual machine name')
    end

    config[:chef_node_name] = vmname unless get_config(:chef_node_name)

    vim_connection

    base_folder = find_folder(get_config(:folder))

    vm = traverse_folders_for_vm(base_folder, vmname) || fatal_exit("VM #{vmname} not found")

    vm.PowerOffVM_Task.wait_for_completion unless vm.runtime.powerState == 'poweredOff'
    vm.Destroy_Task
    puts "Deleted virtual machine #{vmname}"

    if config[:purge]
      destroy_item(Chef::Node, config[:chef_node_name], 'node')
      destroy_item(Chef::ApiClient, config[:chef_node_name], 'client')
    else
      puts "Corresponding node and client for the #{vmname} server were not deleted and remain registered with the Chef Server"
    end
  end
end
