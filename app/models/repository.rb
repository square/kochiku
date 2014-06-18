require 'remote_server'

# This Repository class should only concern itself with persisting and acting on
# Repository records in the database. All non-database operations should go
# through the RemoteServer classes.
class Repository < ActiveRecord::Base
  has_many :projects, :dependent => :destroy
  validates_presence_of :host, :name, :url
  validates_uniqueness_of :name
  validates_numericality_of :timeout, :only_integer => true
  validates_inclusion_of :timeout, in: 0..1440, message: "the maximum timeout allowed is 1440 seconds"

  validates_uniqueness_of :url, :allow_blank => true
  validate :url_against_remote_servers

  def self.lookup_by_url(url)
    git_server_settings = Settings.git_server(url)
    remote_server = RemoteServer.for_url(url)
    repository_namespace = remote_server.attributes.fetch(:repository_namespace)
    repository_name = remote_server.attributes.fetch(:repository_name)

    Repository.where(host: [git_server_settings.host, *git_server_settings.aliases].compact,
                     namespace: repository_namespace,
                     name: repository_name).first
  end

  # Setting a URL will extract values for host, namespace, and name. This
  # should not overwrite values for those attributes that were set in the same
  # session.
  def url=(value)
    # this column is deprecated; eventually url will just be a virtual attribute
    write_attribute(:url, value)

    return unless RemoteServer.parseable_url?(value)

    attrs_from_remote_server = RemoteServer.for_url(value).attributes
    self.host = attrs_from_remote_server[:host] unless host_changed?
    self.namespace = attrs_from_remote_server[:repository_namespace] unless namespace_changed?
    self.name = attrs_from_remote_server[:repository_name] unless name_changed?
  end

  def remote_server
    @remote_server ||= RemoteServer.for_url(url)
  end

  delegate :base_html_url, :base_api_url, :sha_for_branch, to: :remote_server

  def main_project
    projects.where(name: name).first
  end

  def url_for_fetching
    GitRepo.fetch_url(url)
  end

  def repo_cache_name
    repo_cache_dir || "#{name}-cache"
  end

  def promotion_refs
    on_green_update.split(",").map(&:strip).reject(&:blank?)
  end

  def interested_github_events
    event_types = ['pull_request']
    event_types << 'push' if run_ci
    event_types
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

  private

  def url_against_remote_servers
    return unless url.present?

    unless RemoteServer.parseable_url?(url)
      errors.add(:url, 'is not in a format supported by Kochiku')
    end
  end
end
