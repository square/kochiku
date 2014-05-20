require 'settings_accessor'

describe SettingsAccessor do
  describe 'kochiku_protocol' do
    it 'returns https when use_https is truthy' do
      settings = SettingsAccessor.new("use_https: true")
      expect(settings.kochiku_protocol).to eq("https")
    end

    it 'returns https when use_https is false' do
      settings = SettingsAccessor.new("use_https: false")
      expect(settings.kochiku_protocol).to eq("http")
    end

    it 'returns https when use_https is not present' do
      settings = SettingsAccessor.new("blah: blah")
      expect(settings.kochiku_protocol).to eq("http")
    end
  end

  it "can list git servers" do
    settings = SettingsAccessor.new(<<-YAML)
    git_servers:
      stash.example.com:
        type: stash
        username: robot
        password_file: /secrets/stash
      github.com:
        type: github
      github-enterprise.example.com:
        type: github
        mirror: 'git://git-mirror.example.com/'
    YAML
    expect(settings.git_servers.keys).
      to match_array(%w{stash.example.com github.com github-enterprise.example.com})
    expect(settings.git_servers['stash.example.com'].type). to eq('stash')
    expect(settings.git_servers['stash.example.com'].username). to eq('robot')
    expect(settings.git_servers['stash.example.com'].password_file). to eq('/secrets/stash')

    expect(settings.git_servers['github-enterprise.example.com'].mirror).
      to eq('git://git-mirror.example.com/')
  end

  it "can look up git servers" do
    settings = SettingsAccessor.new(<<-YAML)
    git_servers:
      stash.example.com:
        type: stash
      github.com:
        type: github
    YAML
    expect(settings.git_server('git@stash.example.com:square/kochiku.git').type).to eq('stash')
    expect(settings.git_server('https://github.com/square/kochiku.git').type).to eq('github')
    expect(settings.git_server('https://foobar.com/square/kochiku.git')).to eq(nil)
  end

  it "can look up git servers via alias" do
    settings = SettingsAccessor.new(<<-YAML)
    git_servers:
      stash.example.com:
        type: stash
        aliases:
          - stash-alias.example.com
          - other-stash-alias.example.com
      github.com:
        type: github
    YAML
    expect(settings.git_server('git@stash-alias.example.com:square/kochiku.git').host).to eq('stash.example.com')
    expect(settings.git_server('git@other-stash-alias.example.com:square/kochiku.git').host).to eq('stash.example.com')
    expect(settings.git_server('git@not-an-alias.example.com:square/kochiku.git')).to eq(nil)
  end

  it "can also give me the host which matched" do
    settings = SettingsAccessor.new(<<-YAML)
    git_servers:
      github.com:
        type: github
    YAML
    expect(settings.git_server('https://github.com/square/kochiku.git').host).to eq('github.com')
  end

  it "still works if git_servers is not in the config file" do
    settings = SettingsAccessor.new("another_setting:\n")
    expect(settings.git_server('https://github.com/square/kochiku.git')).to eq(nil)
  end

  it "still works if a host is listed without any data" do
    settings = SettingsAccessor.new(<<-YAML)
    git_servers:
      git.example.com:
    YAML
    expect(settings.git_server('git@git.example.com:square/kochiku.git').type).to eq(nil)
  end

  it 'respects relative paths for stash password file' do
    settings = SettingsAccessor.new(<<-YAML)
    git_servers:
      stash.example.com:
        password_file: secrets/stash
    YAML
    expect(settings.git_servers['stash.example.com'].password_file).
      to match(%r{/.*/secrets/stash\Z})
  end
end
