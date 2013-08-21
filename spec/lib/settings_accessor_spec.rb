require 'spec_helper'

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
end
