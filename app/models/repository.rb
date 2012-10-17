class Repository < ActiveRecord::Base
  URL_PARSERS = {
    "git@" => /@(.*):(.*)\/(.*)\.git/,
    "git:" => /:\/\/(.*)\/(.*)\/(.*)\.git/,
    "http" => /https?:\/\/(.*)\/(.*)\/([^.]*)\.?/,
  }
  has_many :projects
  serialize :options, Hash
  validates_presence_of :url

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
    options.with_indifferent_access["tmp_dir"] || "#{repository_name}-cache"
  end

  def run_ci=(checkstate)
    options["run_ci"] = (checkstate == "1")
  end

  def run_ci
    options["run_ci"]
  end

  def use_branches_on_green=(checkstate)
    options["use_branches_on_green"] = (checkstate == "1")
  end

  def use_branches_on_green
    options["use_branches_on_green"]
  end

  def promotion_refs
    options["on_green_update"]
  end

  def on_green_update=(tags)
    options["on_green_update"] = tags.split(",")
  end

  def on_green_update
    options["on_green_update"].join(",") if options["on_green_update"]
  end

  def build_pull_requests=(checkstate)
    options["build_pull_requests"] = (checkstate == "1")
  end

  def build_pull_requests
    options["build_pull_requests"]
  end

  def use_spec_and_ci_queues
    options["use_spec_and_ci_queues"]
  end

  private
  def github_url_params
    parser = URL_PARSERS[url.slice(0,4)]
    match = url.match(parser)
    {:host => match[1], :username => match[2], :repository => match[3]}
  end

end
