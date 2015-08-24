require 'spec_helper'

describe BuildHelper do
  include ActionView::Helpers
  include Haml::Helpers
  let(:build) { FactoryGirl.create(:build) }

  describe "#multiple_ruby_versions?" do
    context "with a ruby build with multiple ruby versions" do
      let!(:build_part) { FactoryGirl.create(:build_part, :build_instance => build, :options => options) }
      let!(:build_part2) { FactoryGirl.create(:build_part, :build_instance => build, :options => options2) }
      let(:options) { {"ruby" => "1.9.3-p194"} }
      let(:options2) { {"ruby" => "2.0"} }

      it "returns true" do
        expect(multiple_ruby_versions?(build)).to equal(true)
      end
    end

    context "with a ruby build with only one ruby version" do
      let!(:build_part) { FactoryGirl.create(:build_part, :build_instance => build, :options => options) }
      let(:options) { {"ruby" => "1.9.3-p194"} }

      it "returns false" do
        expect(multiple_ruby_versions?(build)).to equal(false)
      end
    end

    context "with a non-ruby build" do
      let!(:build_part) { FactoryGirl.create(:build_part, :build_instance => build, :options => options) }
      let(:options) { {} }

      it "returns false" do
        expect(multiple_ruby_versions?(build)).to equal(false)
      end
    end
  end

  context "with a ruby build with multiple ruby versions" do
    let!(:build_part) { FactoryGirl.create(:build_part, :build_instance => build, :options => options) }
    let!(:build_part2) { FactoryGirl.create(:build_part, :build_instance => build, :options => options2) }
    let(:options) { {"ruby" => "1.9.3-p194"} }
    let(:options2) { {"ruby" => "2.0"} }

    it "returns the ruby version info" do
      expect(build_metadata_headers(build, true)).to include("Ruby Version")
      expect(build_metadata_values(build, build_part, true)).to include("1.9.3-p194")
    end
  end

  context "with a build only having one target" do
    let!(:build_part) { FactoryGirl.create(:build_part, :build_instance => build, :paths => ['a']) }
    it "returns the info" do
      expect(build_metadata_headers(build, false)).to eq(["Target"])
      expect(build_metadata_values(build, build_part, false)).to include("a")
    end
  end

  context "with a build with paths" do
    let!(:build_part) { FactoryGirl.create(:build_part, :build_instance => build, :paths => ['a', 'b']) }
    it "returns the info" do
      expect(build_metadata_headers(build, false)).to include("Paths")
      metadata_values = build_metadata_values(build, build_part, false).first

      expect(metadata_values).to start_with(build_part.paths.size.to_s)

      doc = Nokogiri::HTML(metadata_values)
      node = doc.at_css('span')
      expect(node['title']).to eq('a, b')
      expect(node.inner_html).to eq("(<b class=\"root\">a</b>, b)")
    end
  end

  context "with a build with multiple chunks" do
    let!(:build_part) { FactoryGirl.create(:build_part, :build_instance => build, :paths => ['a', 'b'],
      :options => {'total_workers' => 5, 'worker_chunk' => 3}) }

    it "displays worker chunk in paths" do
      expect(format_paths(build_part)).to eq("a - Chunk 3 of 5")
    end
  end
end
