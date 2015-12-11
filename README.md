# Requirements

# Environmental
The following environmental variables must be populated, when running container 

 - CATTLE_ACCESS_KEY
 - CATTLE_SECRET_KEY
 - CATTLE_URL
 
Rather than set the environmental variables manually, use the following labels to have rancher automatically do it for you.

    io.rancher.container.create_agent: true
    io.rancher.container.agent.role: environment
 
The following keys must be available on the host metadata

 - depot.internal_domain
 - depot.load_balancer.listen_port