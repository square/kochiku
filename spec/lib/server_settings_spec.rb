require 'spec_helper'

RSpec.describe ServerSettings do

  it "should be able to access the common settings" do
    options = {
      :type => 'github',
      :mirror => 'git://git-mirror.example.com/',
      :aliases => ['alias1.example.com', 'alias2.example.com'],
    }
    settings = ServerSettings.new(options, 'git.example.com')

    expect(settings.host).to eq('git.example.com')
    expect(settings.type).to eq('github')
    expect(settings.mirror).to eq('git://git-mirror.example.com/')
    expect(settings.aliases).to eq(['alias1.example.com', 'alias2.example.com'])
  end

  context "github settings" do
    describe "oauth token" do
      it "should read the file and expose the token" do
        allow(File).to receive(:read).with('/secrets/github_oauth_token').and_return("oauth_token_for_test\n")

        settings = ServerSettings.new({ oauth_token_file: '/secrets/github_oauth_token' }, 'git.example.com')

        expect(settings.oauth_token)
          .to eq('oauth_token_for_test')
      end
    end
  end

  context "stash settings" do
    it 'should work' do
      allow(File).to receive(:read).with('/secrets/stash').and_return("some_password\n")

      options = {
        :type => 'stash',
        :username => 'kochiku',
        :password_file => '/secrets/stash',
      }
      settings = ServerSettings.new(options, 'stash.example.com')

      expect(settings.type).to eq('stash')
      expect(settings.stash_username).to eq('kochiku')
      expect(settings.stash_password).to eq('some_password')
    end

    describe "stash password file" do
      before do
        File.open(File.join(RSpec.configuration.fixture_path, "stash-pass.txt"), 'w') { |f| f.write("fake-stash-password") }
      end
      after do
        File.unlink(File.join(RSpec.configuration.fixture_path, "stash-pass.txt"))
      end

      it 'will work with a relative path' do
        settings = ServerSettings.new({ password_file: 'spec/fixtures/stash-pass.txt' }, 'stash.example.com')
        expect(settings.stash_password).to eq("fake-stash-password")
      end
    end
  end

end
