require 'spec_helper'
require 'secrets'

describe Secrets do
  it "loads the oauth token" do
    Secrets.github_oauth.should_not be_nil
  end

  context 'missing path' do
    let(:file) { 'kochiku-github.yaml' }
    let(:path) { %w(foo bar) }

    it 'blows up with a meaningful message' do
      expect {
        Secrets.get_secret(file, path)
      }.to raise_error("Path does not exist: #{path}")
    end
  end

  context 'missing file' do
    let(:file) { 'foo.bar' }
    let(:path) { %w(foo bar) }

    it 'blows up with a meaningful message' do
      expect {
        Secrets.get_secret(file, path)
      }.to raise_error("File does not exist: #{file}")
    end
  end
end