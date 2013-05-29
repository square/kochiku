class Repository < ActiveRecord::Base
  URL_PARSERS = {
    "git@" => /@(.*):(.*)\/(.*)\.git/,
    "git:" => /:\/\/(.*)\/(.*)\/(.*)\.git/,
    "http" => /https?:\/\/(.*)\/(.*)\/([^.]*)\.?/,
  }
  has_many :projects, :dependent => :destroy
  validates_presence_of :url
  validates_numericality_of :timeout, :only_integer => true
  validates_inclusion_of :timeout, :in => 0..1440

  def main_project
    projects.where(name: repository_name).first
  end

  def base_html_url
    params = github_url_params
    "https://#{params[:host]}/#{params[:username]}/#{params[:repository]}"
  end

  def base_api_url
    params = github_url_params
    "https://#{params[:host]}/api/v3/repos/#{params[:username]}/#{params[:repository]}"
  end

  def repository_name
    github_url_params[:repository]
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

  def self.covert_to_ssh_url(url)
    params = Repository.github_url_params(url)
    "git@#{params[:host]}:#{params[:username]}/#{params[:repository]}.git"
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

  private

  def github_url_params
    Repository.github_url_params(url)
  end

  def self.github_url_params(url)
    parser = URL_PARSERS[url.slice(0,4)]
    match = url.match(parser)
    {:host => match[1], :username => match[2], :repository => match[3]}
  end
end
