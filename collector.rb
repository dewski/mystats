require 'rubygems'

require 'bundler/setup'
Bundler.require

require_relative './stats'
require_relative './graphite'

# Setup redis
REDIS = Redis.new(:host => '127.0.0.1', :port => ENV['GH_REDIS_PORT'].to_i)
Stats.redis = REDIS

# Gauges
itunes = ITunes::Library.load('/Users/dewski/Music/iTunes/iTunes Music Library.xml')
%w(music movies tv_shows podcasts books).each do |type|
  Stats.gauge("itunes.#{type}.all", itunes.send(type).size)
end

Stats.gauge('itunes.plays.all', itunes.tracks.collect(&:play_count).inject(&:+))

Graphite.publish Stats.to_hash[:gauges]
