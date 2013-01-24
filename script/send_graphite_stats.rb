#!/usr/bin/env ruby

require 'bundler/setup'

require 'resque'
require 'socket'
require 'thread'

def send_to_graphite(graphite_host, metrics)
  begin
    socket = TCPSocket.new(graphite_host, 2003)
    metrics.each do |metric|
      # puts "sending #{metric} to #{graphite_host}"
      socket.puts(metric)
    end
  ensure
    socket.close if socket
  end
end

Resque.redis.namespace = "resque:kochiku"
resque_info = Resque.info

current_time = Time.now.to_i

metrics = [
    "nodes.macbuild_master_sfo_squareup_com.resque.workers #{resque_info[:workers]} #{current_time}",
    "nodes.macbuild_master_sfo_squareup_com.resque.working #{resque_info[:working]} #{current_time}",
    "nodes.macbuild_master_sfo_squareup_com.resque.pending #{resque_info[:pending]} #{current_time}"
]

send_to_graphite("graphite.squareup.com", metrics)