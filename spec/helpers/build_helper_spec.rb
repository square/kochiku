require 'spec_helper'

describe BuildHelper do
  include ActionView::Helpers
  include Haml::Helpers
  let(:build) { FactoryGirl.create(:build, :project => project) }
  let(:project) { FactoryGirl.create(:project, :repository => repository) }
  let(:repository) { FactoryGirl.create(:repository, :url => "git@git.example.com:square/web.git")}

  context "with a ruby build" do
    let!(:build_part) { FactoryGirl.create(:build_part, :build_instance => build, :options => options) }
    let(:options) { {"language" => "ruby", "ruby" => "1.9.3-p194"} }
    it "returns the ruby version info" do
      expect(build_metadata_headers(build)).to include("Ruby Version")
      expect(build_metadata_values(build, build_part)).to include("1.9.3-p194")
    end
  end

  context "with a build only having one target" do
    let!(:build_part) { FactoryGirl.create(:build_part, :build_instance => build, :paths => ['a']) }
    it "returns the info" do
      expect(build_metadata_headers(build)).to eq(["Target"])
      expect(build_metadata_values(build, build_part)).to include("a")
    end
  end

  context "with a build with paths" do
    let!(:build_part) { FactoryGirl.create(:build_part, :build_instance => build, :paths => ['a', 'b']) }
    it "returns the info" do
      expect(build_metadata_headers(build)).to include("Paths")
      metadata_values = build_metadata_values(build, build_part).first

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
