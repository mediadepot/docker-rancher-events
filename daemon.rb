#!/usr/bin/env ruby
require 'rubygems'        # if you use RubyGems
require 'daemons'

Daemons.run('events.rb')