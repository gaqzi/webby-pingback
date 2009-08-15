#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
$KCODE = 'u'

require 'xmlrpc/server'
require 'webby-pingback'

s = XMLRPC::CGIServer.new
s.add_handler('pingback.ping') do |source, target|
  pinger = Pingback::Receiver.new(source, target)
  {:message => pinger.response_message}
end

s.set_default_handler do |name, *args|
  raise XMLRPC::FaultException.new(-99, "Method #{name} missing or wrong number of parameters")
end

s.serve

