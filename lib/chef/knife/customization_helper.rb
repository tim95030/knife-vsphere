#
# Author:: Malte Heidenreich (https://github.com/mheidenr)
# License:: Apache License, Version 2.0
#

module CustomizationHelper
  def CustomizationHelper.wait_for_sysprep(vm, vim_connection, timeout, sleep_time)
    vem = vim_connection.serviceContent.eventManager

    wait = true
    waited_seconds = 0

    print 'Waiting for sysprep...'
    while wait do
      events = query_customization_succeeded(vm, vem)

      if events.size > 0
        events.each do |e|
          puts "\n#{e.fullFormattedMessage}"
        end
        wait = false
      elsif waited_seconds >= timeout
        abort "\nCustomization of VM #{vm.name} not succeeded within #{timeout} seconds."
      else
        print '.'
        sleep(sleep_time)
        waited_seconds += sleep_time
      end
    end
  end

  def CustomizationHelper.query_customization_succeeded(vm, vem)
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
