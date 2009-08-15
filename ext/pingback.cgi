#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
$KCODE = 'u'

module Pingback
Conf = {
  :db => 'path-to-sqlite-datbase-that-is-writable-by-server'
  :forum_api_key => 'long string from disqus, use raketasks to get'
}
end 

require 'rubygems'
require 'webby-pingback-xmlrpc.cgi'
