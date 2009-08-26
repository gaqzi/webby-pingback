# -*- coding: utf-8 -*-

require 'webby-pingback'

Loquacious.configuration_for(:webby) do
  desc 'The find attributes to search for new blog posts to ping with the webby-pingback gem'
  pingback_find [:all, {:blog_post => true, :pingback_done => false}]

  desc 'The xpath expression used to find links in your new post to ping with the webby-pingback gem'
  pingback_find_links_expression '/html/body//a[@href]'
end

namespace :pingback do
  desc 'Ping all links in all new blogposts which hasn\'t been processed'
  task :ping do
    urls = Pingback.find_links

    unless urls.empty?
      urls.each do |page, urls|
        pinger = Pingback::Sender.new("#{Webby.site.base}#{page.url}", urls)
        pinger.start
        Pingback.toggle_trackback_done(page.path)
      end
    end
  end

  desc 'Print out links to ping next time you send out pings'
  task :print_outgoing_links do
    urls = Pingback.find_links
    urls.each do |page, urls|
      puts page.url + ':'
      urls.each {|url| puts "\t#{url}" }
    end
  end

  desc 'Fetches the Disqus forum key, needs the User API key'
  task :fetch_disqus_forum_key do
    require 'open-uri'
    require 'json'
    disqus_url = 'http://disqus.com/api/'

    print 'Disqus user API key: '
    user_key = STDIN.gets.strip

    forum_list = JSON.parse(open("#{disqus_url}get_forum_list/?user_api_key=#{user_key}").read)
    forum_id = if forum_list['message'].size > 2
                 puts 'Available shortnames:'
                 forum_list['message'].each_with_index {|x, i| puts "\t#{i + 1}) #{x['shortname']}" }

                 print 'Fetch shortname # '
                 num = STDIN.gets.strip
                 forum_list['message'][num.to_i - 1]['id']
               else
                 forum_list['message'][0]['id']
               end

    if forum_id
      forum_api_key = JSON.parse(open("#{disqus_url}get_forum_api_key/?user_api_key=#{user_key}&forum_id=#{forum_id}").read)
      if forum_api_key['succeeded']
        puts "Forum api key: #{forum_api_key['message']}"
      else
        STDERR.puts 'Unknown error:'
        STDERR.puts forum_api_key.inspect
      end
    end
  end
end

module Pingback
  def self.find_links
    Webby.load_files
    db = Webby::Resources.pages.find(*Webby.site.pingback_find)
    output = []
    db.each do |page|
      doc = Hpricot(File.read(File.join(Webby.site.output_dir, page.url)))
      urls = doc.search(Webby.site.pingback_find_links_expression).inject([]) do |memo, a|
        if a['href'] == ("#{Webby.site.base}/")
          memo
        else
          memo << a['href']
        end
     end.uniq # /doc
      output << [page, urls]
    end

    output
  end
end
