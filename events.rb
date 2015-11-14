require 'docker'
require 'net/http'
require 'uri'
require 'pp'
puts '#########################################################################'
pp Docker.version
pp Docker.info
puts '#########################################################################'

# Shortcut
uri = URI.parse('http://rancher-metadata/2015-07-25/containers')
response = Net::HTTP.get_response(uri)
pp response.code             # => 301
pp response.body

uri = URI.parse('http://rancher-metadata/2015-07-25/services')
response = Net::HTTP.get_response(uri)
pp response.code             # => 301
pp response.body

uri = URI.parse('http://rancher-metadata/2015-07-25/stacks')
response = Net::HTTP.get_response(uri)
pp response.code             # => 301
pp response.body

puts 'Watching for events'
Docker.options[:read_timeout] = 3600 # listen for 1 hour before timing out.
Docker::Event.stream { |event|
  # container events = delete, import, pull, push, tag, untag
  # image events = attach, commit, copy, create, destroy, die, exec_create, exec_start, export, kill, oom, pause, rename, resize, restart, start, stop, top, unpause

  #only listen to specific container events
  #based on this graph https://docs.docker.com/engine/reference/api/docker_remote_api/
  if event.status == 'start' #skip
    #look up the container using the rancher metadata service.


  end

  container = Docker::Container.get(event.id)
  puts container.json

  break
}


