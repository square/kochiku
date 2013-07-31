require 'uri'
require 'net/http'
require 'secrets'

class GithubRequest
  OAUTH_TOKEN = Secrets.github_oauth
  AUTH = {"Authorization" => "token #{OAUTH_TOKEN}"}

  def self.post(uri, args)
    make_request(:post, uri, [args.to_json, AUTH])
  end

  def self.patch(uri, args)
    make_request(:patch, uri, [args.to_json, AUTH])
  end

  def self.get(uri)
    make_request(:get, uri, [AUTH])
  end

  private

  def self.make_request(method, uri, args)
    body = nil
    Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
      response = http.send(method, uri.path, *args)
      body = response.body
      Rails.logger.info("Github response: #{response.inspect}")
      Rails.logger.info("Github response body: #{body.inspect}")
      raise body unless response.is_a? Net::HTTPSuccess
    end
    body
  end
end
