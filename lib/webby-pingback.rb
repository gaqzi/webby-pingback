#!/usr/bin/env ruby -w
# -*- coding: utf-8 -*-
$KCODE = 'u'

require 'uri'
require 'net/http'
require 'xmlrpc/client'
require 'open-uri'

require 'hpricot'
require 'amalgalite'
require 'json'

# This modules expects there to be a constant called Conf that is a
# hash with two values:
#
# :db::            Path to the SQLite database file
# :forum_api_key:: The Disqus forum api key to fetch the trackback url
#
module Pingback
  # So we don't try to ping twice!
  def self.toggle_trackback_done(filename, mode = true)
    File.open(filename, 'r+') do |file|
      pos = file.each_line do |line|
        break pos if line.match(/^trackback_done: (\w+)/)
        pos = file.pos
      end

      file.seek(pos + 16)
      file.write(' true') # Has to be 5 chars to cover all of false :)
    end
  end

  class Sender
    # +source_url+ is the page that contains outgoing links.
    # +urls+ are the links on that page. +urls+ can also be added dynamically
    # by using +obj.urls << 'url'.
    def initialize(source_url, urls = [])
      @source_url = source_url
      @urls       = ([] << urls).flatten
    end
    attr_accessor :urls

    # Tries to find a pingback url from a given URL. If found ping it.
    def start(verbose = false)
      @urls.each do |url|
        pingback_url = find_pingback_url(url)
        if pingback_url
          send_ping(pingback_url, url)
        end
      end
    end

    # From a given URL try to find a pingback source from HTTP Header,
    # if not found try to download the page and look for a
    # <link rel="pingback"> element and use that.
    def find_pingback_url(url)
      res = fetch_pingback_url(url)
      if res['X-Pingback'].nil?
        res = fetch_pingback_url(url, :Get)
        doc = Hpricot(res.body)
        (doc/"//link[@rel='pingback']")[0]['href'] rescue false
      else
        res['X-Pingback']
      end
    end

    private
    # Connect to +url+ with HTTP-method +type+ and return the result-object.
    def fetch_pingback_url(url, type = :Head)
      uri = URI.parse url
      Net::HTTP.start(uri.host, uri.port) do |http|
        http.request(Net::HTTP.const_get(type).new(uri.path))
      end
    end

    # Using the XML-RPC protocoll send a ping.
    # +xmlrpc_uri+ is the XML-RPC endpoint
    # +target+ is the url that we're linking to and want to tell the endpoint
    def send_ping(xmlrpc_uri, target)
      uri = URI.parse(xmlrpc_uri)
      server = XMLRPC::Client.new(uri.host, uri.path, uri.port)
      begin
        result = server.call('pingback.ping',
                             @source_url,
                             target)
        puts "#{uri.host}#{uri.path}: #{result['message']}"
      rescue XMLRPC::FaultException => e
        puts "#{uri.host}#{uri.path}: Error -- #{e.message}"
      end
    end
  end # / Sender

  class Receiver
    def initialize(source, target)
      @@db               = Amalgalite::Database.new(Pingback::Conf[:db])
      @@forum_api_key    = Pingback::Conf[:forum_api_key]
      @source            = source
      @target            = target
      @response_message  = ''

      db_schema
      if pingback_exists?
        @response_message = 'The pingback has already been registered'
        return true
      end

      trackback_url = fetch_trackback_url()
      if trackback_url.nil?
        @response_message = 'The specified target URI cannot be used as a target.'
        return false
      end

      trackback_data = fetch_source_data()
      if trackback_data[:excerpt].empty?
        @response_message = 'No link to target page!'
        return false
      end

      send_trackback(trackback_url, trackback_data)
    end
    attr :response_message

    private
    def pingback_exists?
      !@@db.execute('SELECT id FROM received_pingbacks
                       WHERE source_url = ?
                         AND target_url = ? ', @source, @target).empty?
    end

    # Looks for the link to the target page so we know it's not just a spambot
    # trying to link us
    def fetch_source_data
      doc = Hpricot(open(@source))
      p doc
      {
        :excerpt  => (doc/"//a[@href='#{@target}']/..").inner_html,
        :title    => (doc/'//title').inner_html,
        :url      => @source
      }
    end

    def send_trackback(url, data)
      uri = URI.parse url
      res = Net::HTTP.start(uri.host, uri.port) do |http|
        req = Net::HTTP::Post.new(uri.path)
        req.form_data = data
        req['Content-Type'] = 'application/x-www-form-urlencoded; charset=utf-8'
        http.request req
      end

      doc = Hpricot.XML(res.body)
      if res.code == '200' and (doc/'//error')[0].inner_html == '0'
        record_trackback(1)
        @response_message = 'OK'
      else
        record_trackback(0, doc.to_html)
        @response_message = 'Unknown error ' + doc.to_html
      end
    end

    def record_trackback(status, message = nil)
      @@db.execute('INSERT INTO received_pingbacks (source_url, target_url, status, message)
                      VALUES (?, ?, ?, ?);', @source, @target, status, message)
    end

    def fetch_trackback_url
      res = @@db.execute('SELECT trackback_url FROM trackback_url WHERE target_url = ?', @target)
      if res.empty?
        url = fetch_disqus_trackback_url
        @@db.execute('INSERT INTO trackback_url (target_url, trackback_url) VALUES (?, ?)', @target, url) if url
        return url
      else
        res.flatten[0]
      end
    end

    def fetch_disqus_trackback_url
      data = JSON.parse(open("http://disqus.com/api/get_thread_by_url/?forum_api_key=#{@@forum_api_key}&url=#{@target}").read)
      if data['succeeded'] and not data['message'].nil?
        x = data['message']
        return "http://#{x['forum_obj']['shortname']}.disqus.com/#{x['slug']}/trackback/"
      else
        nil
      end
    end

    def db_schema
      if @@db.schema.tables.empty?
        @@db.execute_batch('CREATE TABLE received_pingbacks (
                              id INTEGER AUTO INCREMENT PRIMARY KEY,
                              source_url VARCHAR NOT NULL,
                              target_url VARCHAT NOT NULL,
                              status     INTEGER DEFAULT 0,
                              message    VARCHAR NULL
                            );

                            CREATE TABLE trackback_url (
                              target_url VARCHAR NOT NULL PRIMARY KEY,
                              trackback_url VARCHAR NOT NULL
                            );

                            CREATE TABLE version (number INTEGER);
                            INSERT INTO version VALUES(1);')
      end
    end
  end # /Receiver
end # /Pingback
