require 'remote_server/stash'
require 'remote_server/github'

class Repository < ActiveRecord::Base
  UnknownServer = Class.new(RuntimeError)

  has_many :projects, :dependent => :destroy
  validates_presence_of :url
  validates_uniqueness_of :repository_name
  validates_numericality_of :timeout, :only_integer => true
  validates_inclusion_of :timeout, :in => 0..1440

  before_validation :set_repository_name

  def remote_server
    self.class.remote_server_for(url).new(self)
  end

  def main_project
    projects.where(name: repository_name).first
  end

  delegate :base_html_url, :base_api_url, to: :remote_server

  # Where to fetch from (git mirror if defined, otherwise the regular git url)
  def url_for_fetching
    server = Settings.git_server(url)
    if server.mirror.present?
      url.gsub(%r{(git@|https://).*?(:|/)}, server.mirror)
    else
      url
    end
  end

  def set_repository_name
    if self.repository_name.blank?
      self.repository_name = project_params[:repository]
    end
  end

  def repo_cache_name
    repo_cache_dir || "#{repository_name}-cache"
  end

  def promotion_refs
    on_green_update.split(",").map(&:strip).reject(&:blank?)
  end

  def interested_github_events
    event_types = ['pull_request']
    event_types << 'push' if run_ci
    event_types
  end

  def self.remote_server_for(url)
    server = Settings.git_server(url)

    raise UnknownServer, url unless server

    case server.type
      when 'stash'
        RemoteServer::Stash
      when 'github'
        RemoteServer::Github
      else
        raise "unknown server type #{type}"
    end
  end

  # Public: transforms the given url into the format Kochiku prefers for the
  # RemoteServer hosting the repository.
  #
  # Returns: the url tranformed into the preferred format as a String.
  def self.canonical_repository_url(url)
    remote_server_class = remote_server_for(url)
    remote_server_class.canonical_repository_url_for(url)
  end

  def has_on_success_script?
    on_success_script.to_s.strip.present?
  end

  def has_on_success_note?
    on_success_note.to_s.strip.present?
  end

  # Public: attempts to lookup a build for the commit under any of the
  # repository's projects. This is done as an optimization since the contents
  # of the commit are guaranteed to not have changed.
  #
  # Returns: Build AR object or nil
  def build_for_commit(sha)
    Build.joins(:project).where(:ref => sha, 'projects.repository_id' => self.id).first
  end

  def project_params
    Repository.project_params(url)
  end

  private

  def self.project_params(url)
    return {} unless url.present?

    remote_server_for(url).project_params(url)
  end
end
