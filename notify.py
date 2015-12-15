import logging
import json
import requests
import os

log = logging.getLogger("listener")

class Notify:

    def __init__(self, service_info, state):
        self.service_info = service_info
        self.state = state
        self.stack_name = self.service_info['data']['name']

    def send(self):

        pushover_api_key = os.getenv('PUSHOVER_API_KEY')
        if pushover_api_key:
            self.pushover_send(pushover_api_key)

    def pushover_send(self, pushover_api_key):

        message = self.stack_name.capitalize() + ' has ' + self.state

        requests.post("https://api.pushover.net/1/messages.json",
          data={
            "token": "aNiH7or6Q5F1ennDtQpSvhbtY4ot6C",
            "user": pushover_api_key,
            "message": message
        })
