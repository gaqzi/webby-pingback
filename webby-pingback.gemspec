# -*- coding: utf-8 -*-
Gem::Specification.new do |s|
  s.name	 = "webby-pingback"
  s.version	 = "1.0.1"
  s.date	 = Time.now.strftime('%Y-%m-%d')
  s.description	 = "Using Webby and some custom meta-data tags enable pingbacks to blogs and pages"
  s.authors	 = ["Björn Andersson"]
  s.email	 = "ba@sanitarium.se"
  s.homepage	 = "http://github.com/ba/webby-pingback"
  s.summary      = s.description
  s.require_path = 'lib'
  s.has_rdoc	 = false
  s.files	 = %w[README.textile tasks/pingback.rake webby-pingback.gemspec ext/pingback.cgi lib/webby-pingback-rake.rb lib/webby-pingback-xmlrpc.cgi.rb lib/webby-pingback.rb]
  s.add_dependency('amalgalite',  '>= 0.10.2')
  s.add_dependency('json',        '>= 1.1.7')
  s.add_dependency('hpricot',     '>= 0.8.1')
end

