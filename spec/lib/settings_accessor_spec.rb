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

  it 'loads stash settings' do
    settings = SettingsAccessor.new(<<-YAML)
    stash:
      username: robot
      password_file: /secrets/stash
      host: example.com
    YAML
    expect(settings.stash_username).to eq("robot")
    expect(settings.stash_password_file).to eq('/secrets/stash')
    expect(settings.stash_host).to eq("example.com")
  end

  it 'respects relative paths for stash password file' do
    settings = SettingsAccessor.new(<<-YAML)
    stash:
      password_file: secrets/stash
    YAML
    expect(settings.stash_password_file).to match(%r{/.*/secrets/stash\Z})
  end
end
