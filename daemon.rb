#!/usr/bin/env ruby
require 'rubygems'        # if you use RubyGems
require 'daemons'


daemon_options = {
    :app_name   => 'events', #this must match the daemon_name in chef !!!!!
    :log_dir    => '/var/log/',
    :dir_mode   => :script,
    :multiple   => false,
    :backtrace  => true,
    :monitor    => false
}

Daemons.run('events.rb', daemon_options)