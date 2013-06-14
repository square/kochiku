require 'spec_helper'

describe GitRepo do
  let(:repository) { FactoryGirl.create(:repository) }
  let(:repo_uri) { repository.base_api_url }
  let(:branch) { "test/branch" }
  let(:branch_head_sha) { "4b41fe773057b2f1e2063eb94814d32699a34541" }

  before do
    repo_name = repository.repository_name
    build_ref_info = <<RESPONSE
{
  "ref": "refs/heads/#{branch}",
  "url": "https://git.squareup.com/api/v3/repos/square/web/git/refs/heads/#{branch}",
  "object": {
    "sha": "#{branch_head_sha}",
    "type": "commit",
    "url": "https://git.squareup.com/api/v3/repos/square/web/git/commits/#{branch_head_sha}"
  }
}
RESPONSE

    stub_request(:get, "#{repo_uri}/git/refs/heads/#{branch}").to_return(:status => 200, :body => build_ref_info)
  end

  describe "#sha_for_branch" do
    let(:subject) { GitRepo.sha_for_branch(repository, branch) }

    it "returns nil for non-existant repo" do
      bad_repo = FactoryGirl.create(:repository)
      bad_repo_uri = bad_repo.base_api_url
      bad_repo_response = '{ "message": "Not Found" }'
      stub_request(:get, "#{bad_repo_uri}/git/refs/heads/#{branch}").to_return(:status => 200, :body => bad_repo_response)

      repository = bad_repo
      subject.should be_nil
    end

    it "returns nil with non-existant branch" do
      branch { "nonexistant-branch" } # How to change this and affect subject?
      stub_request(:get, "#{repo_uri}/git/refs/heads/#{branch}").to_return(:status => 200, :body => '{ "message": "Not Found" }')

      GitRepo.sha_for_branch(repository, branch).should be_nil
    end

    it "returns the HEAD SHA for the branch" do
      subject.should == branch_head_sha
    end
  end
end