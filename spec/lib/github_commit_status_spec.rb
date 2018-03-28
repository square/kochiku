require 'spec_helper'

describe GithubCommitStatus do
  subject { GithubCommitStatus.new(build, oauth_token) }
  let(:oauth_token) { "my_test_token" }
  let(:build) { FactoryGirl.create(:build) }

  before do
    settings = SettingsAccessor.new(<<-YAML)
    git_servers:
      git.example.com:
        type: github
      github.com:
        type: github
    YAML
    stub_const "Settings", settings
  end

  it "marks a build as pending" do
    build.update_attributes!(:state => 'running')
    expect(GithubRequest).to receive(:post)
      .with(%r|/statuses/#{build.ref}|,
            hash_including(:state => 'pending'),
            oauth_token
           ).and_return(commit_status_response)
    subject.update_commit_status!
  end

  it "marks a build as success" do
    build.update_attributes!(:state => 'succeeded')
    expect(GithubRequest).to receive(:post)
      .with(%r|/statuses/#{build.ref}|,
            hash_including(:state => 'success'),
            oauth_token
           ).and_return(commit_status_response)
    subject.update_commit_status!
  end

  it "marks a build as failure" do
    build.update_attributes!(:state => 'failed')
    expect(GithubRequest).to receive(:post)
      .with(%r|/statuses/#{build.ref}|,
            hash_including(:state => 'failure'),
            oauth_token
           ).and_return(commit_status_response)
    subject.update_commit_status!
  end

  it "uses a repos github url" do
    build.branch_record.update_attributes!(:repository => FactoryGirl.create(:repository, :url => "git@github.com:square/kochiku-worker.git"))
    build.update_attributes!(:state => 'failed')
    build.reload
    expect(GithubRequest).to receive(:post)
      .with("https://api.github.com/repos/square/kochiku-worker/statuses/#{build.ref}",
            anything, anything).and_return(commit_status_response)
    subject.update_commit_status!
  end

  def commit_status_response
    '{"description":"Build is running","creator":{"gravatar_id":"56fdde43fb3bd6cf62bbec24dc8cb682","login":"nolan","url":"https://git.example.com/api/v3/users/nolan","avatar_url":"https://secure.gravatar.com/avatar/56fdde43fb3bd6cf62bbec24dc8cb682?d=https://git.example.com%2Fimages%2Fgravatars%2Fgravatar-user-420.png","id":41},"updated_at":"2012-10-06T02:59:18Z","created_at":"2012-10-06T02:59:18Z","state":"success","url":"https://git.example.com/api/v3/repos/square/web/statuses/22","target_url":"https://kochiku.example.com/square/web/builds/5510","id":22}'
  end
end
