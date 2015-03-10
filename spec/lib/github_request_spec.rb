require 'spec_helper'
require 'github_request'

describe GithubRequest do
  let(:url) { "https://git.example.com/api/something-or-other" }
  let(:oauth_token) { "my_test_token" }

  RSpec.shared_examples "a github api request" do
    it "should properly include oauth token in header" do
      stub_request(http_verb, url).with do |request|
        expect(request.headers["Authorization"]).to eq("token #{oauth_token}")
        true
      end

      subject
    end

    it "should specify Github API v3" do
      stub_request(http_verb, url).with do |request|
        expect(request.headers["Accept"]).to eq("application/vnd.github.v3+json")
        true
      end

      subject
    end
  end

  RSpec.shared_examples "a modifying github api request" do
    it "should JSON encode request data" do

      stub_request(http_verb, url).with do |request|
        body = JSON.parse(request.body)
        expect(body).to eq(request_data)
        true
      end

      subject
    end
  end

  describe ".get" do
    let (:http_verb) { :get }
    subject {
      GithubRequest.get(url, oauth_token)
    }

    include_examples "a github api request"
  end

  describe ".post" do
    let (:http_verb) { :post }
    let (:request_data) { {"arg1" => {"arg2" => "value1"}} }
    subject {
      GithubRequest.post(url, request_data, oauth_token)
    }

    include_examples "a github api request"
    include_examples "a modifying github api request"
  end

  describe ".patch" do
    let (:http_verb) { :patch }
    let (:request_data) { {"arg1" => {"arg2" => "value1"}} }
    subject {
      GithubRequest.patch(url, request_data, oauth_token)
    }

    include_examples "a github api request"
    include_examples "a modifying github api request"
  end
end
