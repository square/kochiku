#!/usr/bin/env ruby

# this file lives at git@git.squareup.com:square/kochiku.git under scripts/clean_nexus_app_releases.rb
#

Dir.chdir "/app/nexus/sonatype-work/nexus/storage/app-releases"

REFS_API_URLS = [
  "https://git.squareup.com/api/v3/repos/square/java/git/refs/heads"
]

BRANCHES_TO_KEEP = [
  /^ci-master-distributed-latest$/,
  /^ci-.*-master\/latest$/, /^deployable-/,
  /\/staging$/, /-staging\/latest$/, /staging-latest$/,
  /\/production$/, /-production\/latest$/, /production-latest$/
]

HOURS_TO_RETAIN = 12

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
  ref_infos.each do |ref_info|
    branch_name = ref_info["ref"].gsub(/^refs\/heads\//, '')
    if BRANCHES_TO_KEEP.any? { |re| re =~ branch_name }
      (shas_to_keep[ref_info["object"]["sha"]] ||= []) << branch_name
    end
  end
end

puts "We want to retain #{shas_to_keep.size} shas."
retaining_because = {}

elderly_shaded_jars = `find . -name .nexus -prune -o -name *-shaded.jar -mmin +#{HOURS_TO_RETAIN * 60}`.split(/\n/)
elderly_shaded_jars.each do |jar|
  jar_file = Pathname(jar)
  next if jar_file.basename.to_s == ".nexus"
  sha_dir = jar_file.dirname
  sha = sha_dir.basename.to_s
  refering_branches = shas_to_keep[sha] || []
  if refering_branches.size > 0
    refering_branches.each { |branch| retaining_because[branch] ||= 0; retaining_because[branch] += 1 }
  else
    puts "Removing #{sha_dir}."
    #FileUtils.rm_rf(sha_dir)
  end
end

retaining_because.keys.sort.each do |branch|
  puts "#{branch} caused #{retaining_because[branch]} artifacts to be retained."
end

File.write("clean-info.txt", "Last cleaned by ~nexus/bin/clean_nexus_app_releases.rb at #{`date`.chomp}.")

