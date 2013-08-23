class Repository < ActiveRecord::Base
  UnknownServer = Class.new(RuntimeError)

  URL_PARSERS = {
    "git@" => /@(.*):(.*)\/(.*)\.git/,
    "git:" => /:\/\/(.*)\/(.*)\/(.*)\.git/,
    "http" => /https?:\/\/(.*)\/(.*)\/([^.]*)\.?/,
    'ssh:' => %r{ssh://git@(.*):(\d+)/(.*)/([^.]+)\.git}
  }
  has_many :projects, :dependent => :destroy
  validates_presence_of :url
  validates_numericality_of :timeout, :only_integer => true
  validates_inclusion_of :timeout, :in => 0..1440

  def remote_server
    self.class.remote_server(url).new(self)
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

  def repository_name
    project_params[:repository]
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

  def self.remote_server(url)
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

  # This is ugly. Is there a better way?
  def self.convert_to_ssh_url(url)
    params = Repository.project_params(url)

    remote_server(url).convert_to_ssh_url(params)
  end

  def has_on_success_script?
    on_success_script.to_s.strip.present?
  end

  def has_on_success_note?
    on_success_note.to_s.strip.present?
  end

  def ci_queue_name
    queue_override.presence || "ci"
  end

  def project_params
    Repository.project_params(url)
  end

  private

  def self.project_params(url)
    # TODO: Move these parsers to RemoteServer classes.
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
end
