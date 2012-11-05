require 'rubygems'

require 'bundler/setup'
Bundler.require

require_relative './stats'
require_relative './graphite'

# Setup redis
REDIS = Redis.new(:host => '127.0.0.1', :port => ENV['GH_REDIS_PORT'].to_i)
Stats.redis = REDIS

# Gaugesafp://10.0.1.4/
hosts = {
  'laptop' => '/Volumes/iTunes/iTunes Music Library.xml',
  'server' => '/Users/admin/Music/iTunes/iTunes Music Library.xml'
}

hosts.each do |host, path|
  next unless File.exists?(path)

  itunes = ITunes::Library.load(path)
  %w(music movies tv_shows podcasts books).each do |type|
    Stats.gauge("itunes.hosts.#{host}.#{type}.all", itunes.send(type).size)
  end

  Stats.gauge("itunes.hosts.#{host}.plays.all", itunes.tracks.collect(&:play_count).inject(&:+))
end


Graphite.publish Stats.to_hash[:gauges]
