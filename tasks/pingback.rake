# -*- coding: utf-8 -*-

require 'webby-pingback'

namespace :pingback do
  desc 'Ping all links in all new blogposts which hasn\'t been processed'
  task :ping do
    Webby.load_files
    db = Webby::Resources.pages.find(:all, :blog_post => true, :trackback_done => false)
    db.each do |page|
      doc = Hpricot(File.read(Webby.site.output_dir + page.url))
      urls = (doc/'/html/body//a[@href]').inject([]) do |memo, a|
        if a['href'] == ("#{Webby.site.base}/") or a['href'].match(/(disqus.com)|(webby.rubyforge.org)/)
          memo
        else
          memo << a['href']
        end
     end.uniq # /doc

      pinger = Pingback::Sender.new("#{Webby.site.base}#{page.url}", urls)
      pinger.start
      Pingback.toggle_trackback_done(page.path)
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
