require 'docker'
require 'net/http'
require 'uri'
require 'pp'
puts '#########################################################################'
pp Docker.version
pp Docker.info
puts '#########################################################################'

# # Shortcut
# uri = URI.parse('http://rancher-metadata/2015-07-25/containers')
# response = Net::HTTP.get_response(uri)
# pp response.code             # => 301
# pp response.body
#
# uri = URI.parse('http://rancher-metadata/2015-07-25/services')
# response = Net::HTTP.get_response(uri)
# pp response.code             # => 301
# pp response.body
#
# uri = URI.parse('http://rancher-metadata/2015-07-25/stacks')
# response = Net::HTTP.get_response(uri)
# pp response.code             # => 301
# pp response.body

puts 'Watching for events'
#should listen and sleep on 10s intervals.
Docker.options[:read_timeout] = 10 # listen for 10 seconds before timing out.
timestamp = Time.now.getutc
loop do
  Docker::Event.since(timestamp) { |event|
    if ['start','stop'].includes?(event.status)
      #this is a container start/stop event, we need to handle it.
      container = Docker::Container.get(event.id)
      labels = container.info['Config']['Labels'] || {}
      pp labels

      #check if the required labels exist:
      # depot.lb.link
      if labels['depot.lb.link'] && labels['io.rancher.stack.name']
        puts "processsing #{event.status} event on service: #{labels['io.rancher.stack.name']}/#{labels['io.rancher.stack_service.name']}"
      end
    end
  }
  timestamp = Time.now.getutc
  sleep 10
end


