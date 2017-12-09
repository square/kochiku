require 'uri'
require 'net/http'

class GithubRequest
  class ResponseError < RuntimeError
    attr_accessor :response
  end

  def self.get(url, oauth_token)
    uri = URI(url)
    request = Net::HTTP::Get.new(uri.request_uri)
    request["Authorization"] = "token #{oauth_token}"
    request["Accept"] = "application/vnd.github.v3+json"
    make_request(uri, request)
  end

  def self.post(url, data, oauth_token)
    uri = URI(url)
    request = Net::HTTP::Post.new(uri.request_uri)
    request.body = data.to_json
    request["Authorization"] = "token #{oauth_token}"
    request["Accept"] = "application/vnd.github.v3+json"
    request["Content-Type"] = "application/json; charset=utf-8"
    make_request(uri, request)
  end

  def self.patch(url, data, oauth_token)
    uri = URI(url)
    request = Net::HTTP::Patch.new(uri.request_uri)
    request.body = data.to_json
    request["Authorization"] = "token #{oauth_token}"
    request["Accept"] = "application/vnd.github.v3+json"
    request["Content-Type"] = "application/json; charset=utf-8"
    make_request(uri, request)
  end

  def self.make_request(uri, request_object)
    Rails.logger.info("Github request: #{request_object.method}, #{uri}")
    body = nil
    Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
      response = http.request(request_object)
      body = response.body
      Rails.logger.info("Github response: #{response.inspect}")
      Rails.logger.info("Github response body: #{body.inspect}")
      unless response.is_a? Net::HTTPSuccess
        response_error = ResponseError.new("response: #{response.class} body: #{body}")
        response_error.response = response
        raise response_error
      end
    end
    body
  end
  private_class_method :make_request
end
