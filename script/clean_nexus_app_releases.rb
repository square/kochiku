#!/usr/bin/env ruby

# this file lives at git@git.squareup.com:square/kochiku.git under scripts/clean_nexus_app_releases.rb
#

RELEASES_DIR = "/app/nexus/sonatype-work/nexus/storage/app-releases"

REFS_API_URLS = [
  "https://git.squareup.com/api/v3/repos/square/java/git/refs/heads"
]

BRANCHES_TO_KEEP = [
  # mtv-styley:
  /^ci-(\w+)-master\/latest$/,
  /^(\w+)-staging\/latest$/,
  /^(\w+)-production\/latest$/,

  # hoist I guess?
  /^deployable-(\w+)$/,
  /^hoist\/(\w+)\/\w+\/staging$/,
  /^hoist\/(\w+)\/\w+\/production/,
]

HOURS_TO_RETAIN = 12

Dir.chdir RELEASES_DIR

puts "Running #{[$0, ARGV].flatten.join(" ")} at #{Time.now.to_s}"
puts ""

require 'uri'
require 'net/http'
require 'json'
require 'pathname'
require 'fileutils'

def dump_disk_info(stage)
  puts "#{stage}: df -h #{RELEASES_DIR}:"
  system "df -h ."
  puts ""

  puts "#{stage}: du -sh #{RELEASES_DIR}:"
  system "du -sh"
  puts ""

  puts "#{stage}: du -sh #{RELEASES_DIR}/com/squareup/*:"
  system "du -sh com/squareup/*"
  puts ""
end

dump_disk_info("before")

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
    BRANCHES_TO_KEEP.each do |branch_regexp|
      branch_regexp.match(branch_name) do |m|
        sha = ref_info["object"]["sha"]
        sha_info = shas_to_keep[sha] ||= { artifacts: {} }
        (sha_info[:artifacts][m[1]] ||= []) << branch_name
      end
    end
  end
end

puts "We want to retain #{shas_to_keep.size} shas."

elderly_shaded_jars = `find . -name .nexus -prune -o -name *-shaded.jar -mmin +#{HOURS_TO_RETAIN * 60}`.split(/\n/)
elderly_shaded_jars.each do |jar|
  jar_file = Pathname(jar)
  next if jar_file.basename.to_s == ".nexus"
  sha_dir = jar_file.dirname
  sha = sha_dir.basename.to_s

  artifact_name = jar_file.parent.parent.basename.to_s

  sha_info = shas_to_keep[sha]
  retain = false
  if sha_info
    sha_info[:artifacts].each do |artifact_to_keep, triggering_branches|
      if artifact_name == artifact_to_keep
        puts "Retaining #{jar_file} because #{triggering_branches.join(", ")}"
        retain = true
      end
    end
  end

  unless retain
    puts "Removing #{sha_dir}"
    FileUtils.rm_rf(sha_dir)
  end
end

dump_disk_info("after")

File.write("clean-info.txt", "Last cleaned by ~nexus/bin/clean_nexus_app_releases.rb at #{`date`.chomp}.")

