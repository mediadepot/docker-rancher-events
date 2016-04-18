#!/usr/bin/env bash
if [ ! -f /srv/rancher-events/env.py ]; then
	#generate the config file for the first time using conf.d
	confd -onetime -backend rancher -prefix /2015-12-19
fi

. /srv/rancher-events/env.sh
python /srv/rancher-events/listener.py