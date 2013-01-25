#!/usr/bin/env ruby

require 'bundler/setup'

require 'resque'
require 'socket'
require 'thread'

def send_to_graphite(graphite_host, metrics)
  begin
    socket = TCPSocket.new(graphite_host, 2003)
    metrics.each do |metric|
      # puts "#{Time.now.to_s}: sending #{metric} to #{graphite_host}"
      socket.puts(metric)
    end
  ensure
    socket.close if socket
  end
end

Resque.redis.namespace = "resque:kochiku"
resque_info = Resque.info

cucumber_queue_size = ["ci-cucumber", "developer-cucumber"].inject(0) { |s, q| s + Resque.size(q) }
spec_queue_size = ["ci-spec", "developer-spec"].inject(0) { |s, q| s + Resque.size(q) }
ci_queue_size = ["ci-osx", "ci"].inject(0) { |s, q| s + Resque.size(q) }

macbuild_spec_count = 0
macbuild_cucumber_count = 0
ec2_spec_count = 0
ec2_cucumber_count = 0
ec2_ci_count = 0

Resque.workers.each do |worker|
  queues = worker.id.split(':')[-1].split(',')
  if worker.id =~ /ec2/
    if queues.include?("ci")
      ec2_ci_count += 1
    elsif queues.include?("ci-spec")
      ec2_spec_count += 1
    elsif queues.include?("ci-cucumber")
      ec2_cucumber_count += 1
    end
  else
    if queues.include?("ci-spec")
      macbuild_spec_count += 1
    elsif queues.include?("ci-cucumber")
      macbuild_cucumber_count += 1
    end
  end
end

current_time = Time.now.to_i

metrics = [
    "nodes.macbuild_master_sfo_squareup_com.resque.workers #{resque_info[:workers]} #{current_time}",
    "nodes.macbuild_master_sfo_squareup_com.resque.working #{resque_info[:working]} #{current_time}",
    "nodes.macbuild_master_sfo_squareup_com.resque.pending #{resque_info[:pending]} #{current_time}",
    "nodes.macbuild_master_sfo_squareup_com.resque.cucumber_queue_size #{cucumber_queue_size} #{current_time}",
    "nodes.macbuild_master_sfo_squareup_com.resque.spec_queue_size #{spec_queue_size} #{current_time}",
    "nodes.macbuild_master_sfo_squareup_com.resque.ci_queue_size #{ci_queue_size} #{current_time}",
    "nodes.macbuild_master_sfo_squareup_com.resque.ec2_spec_count #{ec2_spec_count} #{current_time}",
    "nodes.macbuild_master_sfo_squareup_com.resque.ec2_cucumber_count #{ec2_cucumber_count} #{current_time}",
    "nodes.macbuild_master_sfo_squareup_com.resque.ec2_ci_count #{ec2_ci_count} #{current_time}",
    "nodes.macbuild_master_sfo_squareup_com.resque.macbuild_spec_count #{macbuild_spec_count} #{current_time}",
    "nodes.macbuild_master_sfo_squareup_com.resque.macbuild_cucumber_count #{macbuild_cucumber_count} #{current_time}"
]

send_to_graphite("graphite.squareup.com", metrics)