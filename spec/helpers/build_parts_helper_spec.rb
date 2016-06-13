require 'spec_helper'

describe BuildPartsHelper do
  let(:test_log_gz) { '/some/path/to/test.log.gz' }

  describe "#basename_with_extension" do
    it 'returns the basename with the extension' do
      expect(helper.basename_with_extension(test_log_gz)).to eq("test.log.gz")
    end
  end

  describe "#basename_without_extension" do
    it 'returns the basename without the extension' do
      expect(helper.basename_without_extension(test_log_gz)).to eq("test.log")
    end
  end
end
