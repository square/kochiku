require 'remote_server'

# This Repository class should only concern itself with persisting and acting on
# Repository records in the database. All non-database operations should go
# through the RemoteServer classes.
class Repository < ActiveRecord::Base
  has_many :branches, :dependent => :destroy
  has_many :convergence_branches, -> { where(convergence: true) }, class_name: "Branch"
  validates :host, :name, :url, presence: true
  validates :name, uniqueness: true
  validates :timeout, numericality: { :only_integer => true }
  validates :timeout, inclusion: { in: 0..1440, message: 'The maximum timeout allowed is 1440 minutes' }
  validates :url, uniqueness: true, allow_blank: true
  validate :validate_url_against_remote_servers

  def self.lookup_by_url(url)
    remote_server = RemoteServer.for_url(url)
    repository_namespace = remote_server.attributes.fetch(:repository_namespace)
    repository_name = remote_server.attributes.fetch(:repository_name)
    repository_host_and_aliases = remote_server.attributes.fetch(:possible_hosts)

    Repository.find_by(host: repository_host_and_aliases,
                       namespace: repository_namespace,
                       name: repository_name)
  end

  def self.lookup(host:, namespace:, name:)
    git_server_settings = Settings.git_server(host)

    Repository.find_by(host: [git_server_settings.host, *git_server_settings.aliases].compact,
                       namespace: namespace,
                       name: name)
  end

  # Setting a URL will extract values for host, namespace, and name. This
  # should not overwrite values for those attributes that were set in the same
  # session.
  def url=(value)
    # this column is deprecated; eventually url will just be a virtual attribute
    self[:url] = value

    return unless RemoteServer.parseable_url?(value)
    return unless RemoteServer.valid_git_host?(value)

    attrs_from_remote_server = RemoteServer.for_url(value).attributes
    self.host = attrs_from_remote_server[:host] unless host_changed?
    self.namespace = attrs_from_remote_server[:repository_namespace] unless namespace_changed?
    self.name = attrs_from_remote_server[:repository_name] unless name_changed?
  end

  def remote_server
    @remote_server ||= RemoteServer.for_url(url)
  end

  delegate :base_html_url, :base_api_url, :sha_for_branch, :url_for_fetching, :get_branch_url, :open_pull_request_url, to: :remote_server

  def promotion_refs
    on_green_update.split(",").map(&:strip).reject(&:blank?)
  end

  def interested_github_events
    event_types = ['pull_request']
    event_types << 'push' if run_ci
    event_types
  end

  # Public: attempts to lookup a build for the commit under any of the
  # repository's branches. This is done as an optimization since the contents
  # of the commit are guaranteed to not have changed.
  #
  # Returns: Build AR object or nil
  def build_for_commit(sha)
    Build.joins(:branch_record).find_by(:ref => sha, 'branches.repository_id' => self.id)
  end

  # Public: looks across all of a repository's builds for one with the given
  # SHA. If one does not exist it creates one on the branch given
  #
  # sha    - String: git sha of the commit in question
  # branch - String or AR Branch: if an existing build is not found a new one will be created on this branch
  #
  # Returns: Build AR object
  def ensure_build_exists(sha, branch)
    build = build_for_commit(sha)
    unless build.present?
      build = branch.builds.create!(ref: sha, state: :partitioning)
    end
    build
  end

  def name_with_namespace
    "#{namespace}/#{name}"
  end
  alias to_param name_with_namespace

  private

  def validate_url_against_remote_servers
    return unless url.present?

    if RemoteServer.parseable_url?(url)
      unless RemoteServer.valid_git_host?(url)
        errors.add(:url, "host is not in Kochiku's list of git servers")
      end
    else
      errors.add(:url, 'is not in a format supported by Kochiku')
    end
  end
end
