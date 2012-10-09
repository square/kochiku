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
    parser = URL_PARSERS[url.slice(0,4)]
    match = url.match(parser)
    host = match[1]
    username = match[2]
    repository = match[3]
    "https://#{host}/#{username}/#{repository}"
  end
end
