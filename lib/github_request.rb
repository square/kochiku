require 'uri'
require 'net/http'

class GithubRequest
  OAUTH_TOKEN = "39408724f3a92bd017caa212cc7cf2bbb5ac02b6"
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
    end
    body
  end
end
