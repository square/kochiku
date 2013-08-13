require 'uri'
require 'net/http'
require 'secrets'

class GithubRequest
  OAUTH_TOKEN = Secrets.github_oauth
  AUTH = {"Authorization" => "token #{OAUTH_TOKEN}"}

  class ResponseError < Exception
    attr :reason, :body
  end

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
      unless response.is_a? Net::HTTPSuccess
        response_error = ResponseError.new("response: #{response.class} body: #{body}")
        response_error.reason = response.class
        response_error.body = response.body
        raise response_error
      end
    end
    body
  end
end
