import logging
import json
import requests
import os
from notify import Notify

log = logging.getLogger("listener")

class Processor:
    ignored_resource_types = ['mount', 'ipAddress', 'nic', 'volume', 'port']

    def __init__(self, rancher_event):
        self._raw = rancher_event
        self.event = json.loads(rancher_event)

        self.api_endpoint = os.getenv('CATTLE_URL')
        self.access_key = os.getenv('CATTLE_ACCESS_KEY')
        self.secret_key = os.getenv('CATTLE_SECRET_KEY')
        self.domain = os.getenv('DOMAIN')
        self.external_loadbalancer_http_port = os.getenv('LOADBALANCER_HTTP_LISTEN_PORT', '80')
        self.external_loadbalancer_https_port = os.getenv('LOADBALANCER_HTTPS_LISTEN_PORT', '443')


    def start(self):
        #ignore pings
        if self.event['name'] == 'ping':
            return

        #ignore all resources other than services.
        if self.event['resourceType'] != 'service':
            return

        #for services, we only care if the status has become active, or removed
        if self.event['data']['resource']['state'] == 'active' or self.event['data']['resource']['state'] == 'removed':
            log.info('Detected a change in rancher services. Begin processing.')
            log.info(self._raw)

            #get the current event's stack information
            r = requests.get(self.event['data']['resource']['links']['environment'],
                 auth=(self.access_key, self.secret_key),
                 headers = {'Accept': 'application/json', 'Content-Type': 'application/json'}
                 )
            r.raise_for_status()
            service_stack_response = r.json()

            try:
                notify = Notify(service_stack_response,
                                'started' if self.event['data']['resource']['state'] == 'active' else 'stopped')
                notify.send()
            except:
                log.error('An error occured while trying to notify stack change')
            # list of running stacks, called environments in api
            r = requests.get(self.api_endpoint + '/environments',
                             auth=(self.access_key, self.secret_key),
                             headers = {'Accept': 'application/json', 'Content-Type': 'application/json'}
                             )
            r.raise_for_status()
            stacks_response = r.json()

            loadbalancer_entries = []
            loadbalancer_service = None

            log.info(' -- Finding all Stacks')
            for stack in stacks_response['data']:
                stack_name = stack['name']

                # make sure the stack/environment is active
                if stack['state'] != 'active':
                    log.info(' -- -- Ignoring {0} stack because it\'s not active'.format(stack_name))
                    continue

                if stack_name == 'utility':
                    loadbalancer_service = self.get_utility_loadbalancer(stack)


                depot_services = self.get_stack_services(stack)

                for service in depot_services:

                    port = service['launchConfig'].get('labels',{}).get('depot.lb.port', '80')
                    loadbalancer_entries.append({
                        'serviceId': service['id'],
                        'ports': [
                            stack_name + '.' + self.domain + ':' + self.external_loadbalancer_http_port + '=' + port
                        ]
                    })

            if loadbalancer_service is None:
                raise Exception('Could not find the Utility stack external load balancer. This should never happen')

            log.info(' -- Setting loadbalancer entries:')
            log.info(loadbalancer_entries)
            self.set_loadbalancer_links(loadbalancer_service, loadbalancer_entries)
            log.info('Finished processing')

    def set_loadbalancer_links(self, loadbalancer_service, loadbalancer_entries):

        r = requests.post(loadbalancer_service['actions']['setservicelinks'],
                         auth=(self.access_key, self.secret_key),
                         headers = {'Accept': 'application/json', 'Content-Type': 'application/json'},
                        json={"serviceLinks":loadbalancer_entries}
                         )
        r.raise_for_status()
        log.info(r.json())

    def get_utility_loadbalancer(self, utility_stack):
        log.info(' -- -- Searching for external loadbalancer in utility stack:')

        # get the external loadbalancer service
        r = requests.get(utility_stack['links']['services'],
                     auth=(self.access_key, self.secret_key),
                     headers = {'Accept': 'application/json', 'Content-Type': 'application/json'}
                     )
        r.raise_for_status()
        utility_services_response = r.json()

        #filter out anything thats not the lb service.
        load_balancer = None
        for service_data in utility_services_response['data']:
            if service_data['type'] == 'loadBalancerService' and service_data['name'] == 'lb':
                load_balancer = service_data
                break

        return load_balancer

    def get_stack_services(self, stack):
        log.info(' -- -- Retrieving services in stack: ' + stack['name'])
        #get the current active services
        r = requests.get(stack['links']['services'],
                         auth=(self.access_key, self.secret_key),
                         headers = {'Accept': 'application/json', 'Content-Type': 'application/json'}
                         )
        r.raise_for_status()
        services_response = r.json()
        depot_services = []

        #filter out any services that do not have the depot.lb.link label
        for service_data in services_response['data']:
            if (service_data['type'] != 'service') and (service_data['type'] != 'externalService'): continue
            link = service_data['launchConfig'].get('labels',{}).get('depot.lb.link', 'false')
            if link == 'true':
                depot_services.append(service_data)

        return depot_services

