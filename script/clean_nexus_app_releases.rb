#!/usr/bin/env ruby

REFS_API_URLS = [
  "https://git.squareup.com/api/v3/repos/square/java/git/refs/heads"
]

BRANCHES_TO_KEEP = [
  /^ci-master-distributed-latest$/,
  /^deployable-/,
  /\/staging$/, /-staging\/latest$/, /staging-latest$/,
  /\/production$/, /-production\/latest$/, /production-latest$/
]


require 'uri'
require 'net/http'
require 'json'
require 'pathname'
require 'fileutils'

class GithubRequest
  def self.get(uri)
    make_request(:get, uri, [])
  end

  private

  def self.make_request(method, uri, args)
    body = nil
    Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
      response = http.send(method, uri.path, *args)
      body = response.body
    end
    body
  end
end

shas_to_keep = {}
REFS_API_URLS.each do |url|
  ref_infos = JSON.parse(GithubRequest.get(URI.parse(url)))
  refs_to_keep = ref_infos.select do |ref_info|
    branch_name = ref_info["ref"].gsub(/^\/refs\/heads\//, '')
    BRANCHES_TO_KEEP.any? { |re| re =~ branch_name }
  end

  refs_to_keep.each { |ref_info| shas_to_keep[ref_info["object"]["sha"]] = true }
end

puts "We want to retain #{shas_to_keep.size} shas."

elderly_shaded_jars = `find . -name *-shaded.jar -mtime +2`.split(/\n/)
elderly_shaded_jars.each do |jar|
  sha_dir = Pathname(jar).dirname
  sha = sha_dir.basename.to_s
  unless shas_to_keep.include?(sha)
    puts "Removing #{sha_dir}."
    FileUtils.rm_rf(sha_dir)
  end
end