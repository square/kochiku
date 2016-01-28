require 'colorize'

class AddRepositoryNameAsColumn < ActiveRecord::Migration
  Rails.logger = Logger.new(STDOUT)

  URL_PARSERS = {
    "git@" => /@(.*):(.*)\/(.*)\.git/,
    "git:" => /:\/\/(.*)\/(.*)\/(.*)\.git/,
    "http" => /https?:\/\/(.*)\/(.*)\/([^.]*)\.?/,
    'ssh:' => %r{ssh://git@(.*):(\d+)/(.*)/([^.]+)\.git}
  }.freeze

  class Repository < ActiveRecord::Base
  end

  def project_params(url)
    # TODO: Use the parsers in the RemoteServer classes.
    parser = URL_PARSERS[url.slice(0,4)]
    match = url.match(parser)

    if match.length > 4
      {
        host:       match[1],
        port:       match[2].to_i,
        username:   match[3],
        repository: match[4]
      }
    else
      {
        host:       match[1],
        username:   match[2],
        repository: match[3]
      }
    end
  end

  def old_style_repository_name(url)
    project_params(url)[:repository]
  end

  def up
    add_column :repositories, :repository_name, :string

    Repository.all.each do |repository|
      repository.update_attribute(:repository_name, old_style_repository_name(repository.url))
    end

    repository_count = Repository.all.each_with_object({}) do |repository, duplicates|
      duplicates[repository.repository_name] ||= 0
      duplicates[repository.repository_name] += 1
      duplicates
    end

    duplicates = repository_count.select { |name, count| count > 1 }
    if duplicates.any?
      Rails.logger.warn("")
      Rails.logger.warn("")
      Rails.logger.warn(("*" * 80).yellow)
      Rails.logger.warn("Duplicate repositories detected.".yellow)
    end
    duplicates.each do |name, count|
      Rails.logger.warn("Found #{count} repositories named #{name}. Please rename them.".yellow)
    end
  end

  def down
    remove_column :repositories, :repository_name
  end
end
