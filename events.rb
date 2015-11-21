require 'docker'
require 'net/http'
require 'uri'
require 'pp'
require 'rest-client'
require 'json'
puts '#########################################################################'
pp Docker.version
pp Docker.info
puts '#########################################################################'

raise 'Environmental variable RANCHER_MANAGER_HOSTNAME is required' unless ENV['RANCHER_MANAGER_HOSTNAME']
raise 'Environmental variable RANCHER_API_KEY is required' unless ENV['RANCHER_API_KEY']
raise 'Environmental variable RANCHER_API_SECRET is required' unless ENV['RANCHER_API_SECRET']
raise 'Environmental variable DEPOT_DOMAIN is required' unless ENV['DEPOT_DOMAIN']

def get_default_loadbalancer
  loadbalancer_response_body = RestClient::Request.execute(:method => :get,
                                                      :url => "http://#{ENV['RANCHER_MANAGER_HOSTNAME']}/v1/loadbalancers",
                                                      :user => ENV['RANCHER_API_KEY'],
                                                      :password => ENV['RANCHER_API_SECRET'],
                                                      :headers => {
                                                          'Accept' => 'application/json',
                                                          'Content-Type' => 'application/json'
                                                      }
  )

  loadbalancer_response = JSON.parse(loadbalancer_response_body)
  default_lb = loadbalancer_response['data'].find {|loadbalancer|
    (loadbalancer['type'] == 'loadBalancer') && (loadbalancer['name'] == 'utility_lb')
  }
  return default_lb
end

def get_service_stack_name(service)
  environment_response_body = RestClient::Request.execute(:method => :get,
                                                           :url => service['links']['environment'],
                                                           :user => ENV['RANCHER_API_KEY'],
                                                           :password => ENV['RANCHER_API_SECRET'],
                                                           :headers => {
                                                               'Accept' => 'application/json',
                                                               'Content-Type' => 'application/json'
                                                           }
  )

  environment_response = JSON.parse(environment_response_body)
  return environment_response['name']
end

def generate_loadbalancer_service_links
  #get the current active services using the metadata service.
  service_response_body = RestClient::Request.execute(:method => :get,
                              :url => "http://#{ENV['RANCHER_MANAGER_HOSTNAME']}/v1/services",
                              :user => ENV['RANCHER_API_KEY'],
                              :password => ENV['RANCHER_API_SECRET'],
                              :headers => {
                                  'Accept' => 'application/json',
                                  'Content-Type' => 'application/json'
                              }
  )
  service_response = JSON.parse(service_response_body)

  service_links = []
  service_response['data'].each { |service|
    next if service['type'] != 'service'
    link = service['launchConfig'].get('labels',{}).get('depot.lb.link', 'false')
    if link == 'true'
      port = service['launchConfig'].get('labels',{}).get('depot.lb.port', '80')
      stack_name = get_service_stack_name(service)
      service_links.push({
       'serviceId' => service['id'],
        'ports' => ["#{stack_name}.#{ENV['DEPOT_DOMAIN']}=#{port}"]
      })
    end
  }
end

def set_loadbalancer_service_links(loadbalancer, service_links)
  loadbalancer_service_response_body = RestClient::Request.execute(:method => :get,
                                                          :url => loadbalancer['links']['service'],
                                                          :user => ENV['RANCHER_API_KEY'],
                                                          :password => ENV['RANCHER_API_SECRET'],
                                                          :headers => {
                                                              'Accept' => 'application/json',
                                                              'Content-Type' => 'application/json'
                                                          }
  )

  loadbalancer_service_response = JSON.parse(loadbalancer_service_response_body)

  #now we have to extract the loadbalancer service link post url and post our service links there

  payload = {"serviceLinks" => service_links}.to_json

  set_service_links_response_body = RestClient::Request.execute(:method => :post,
                                                                   :payload => payload,
                                                                   :url => loadbalancer_service_response['actions']['"setservicelinks'],
                                                                   :user => ENV['RANCHER_API_KEY'],
                                                                   :password => ENV['RANCHER_API_SECRET'],
                                                                   :headers => {
                                                                       'Accept' => 'application/json',
                                                                       'Content-Type' => 'application/json'
                                                                   }
  )

  set_service_links_response = JSON.parse(set_service_links_response_body)
  return set_service_links_response

end


# # Shortcut

puts 'Watching for events'
Docker.options[:read_timeout] = nil # listen forever
Docker::Event.stream {|event|
  if ['start','stop'].include?(event.status)
    #this is a container start/stop event, we need to handle it.
    container = Docker::Container.get(event.id)
    labels = container.info['Config']['Labels'] || {}

    #check if the required labels exist:
    # depot.lb.link
    if labels['depot.lb.link'] && labels['io.rancher.stack.name']
      puts "processsing #{event.status} event on service: #{labels['io.rancher.stack_service.name']}"
      puts 'event:'
      pp event
      puts 'containers'
      pp container

      service_links = generate_loadbalancer_service_links()
      puts 'service_links'
      pp service_links

      load_balancer = get_default_loadbalancer()
      puts 'load_balancer'
      pp load_balancer

      resp = set_loadbalancer_service_links(load_balancer, service_links)
      puts 'set_service_links resp'
      pp resp

    end
  end
}


