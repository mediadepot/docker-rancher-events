import websocket
import base64
import os
from processor import Processor
import logging

log = logging.getLogger("listener")


def on_message(ws, message):
    processor = Processor(message)
    processor.start()


def on_error(ws, error):
    raise Exception('Received websocket error: [%s]', error)


def on_close(ws):
    log.info('### Websocket connection closed ###')


def on_open(ws):
    log.info('### Websocket connection opened ###')


if __name__ == "__main__":

    # retrieve api endpoint, access key and secret from environmental variables.
    api_endpoint = os.getenv('CATTLE_URL').replace('http:', 'ws:').replace('https:', 'wss:')
    access_key = os.getenv('CATTLE_ACCESS_KEY')
    secret_key = os.getenv('CATTLE_SECRET_KEY')
    auth_header = 'Authorization: Basic ' + base64.standard_b64encode(access_key + ':' + secret_key).encode(
        'latin1').strip()

    headers = []
    headers.append(auth_header)

    websocket.enableTrace(True)
    ws = websocket.WebSocketApp(api_endpoint + '/subscribe?eventNames=resource.change',
                                header=headers,
                                on_message=on_message,
                                on_error=on_error,
                                on_close=on_close,
                                on_open=on_open)
    log.info('start listening to rancher manager websocket')
    ws.run_forever()
