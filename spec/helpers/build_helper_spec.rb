require 'spec_helper'

describe BuildHelper do
  include ActionView::Helpers
  include Haml::Helpers
  let(:build) { Factory.create(:build, :project => project) }
  let(:project) { Factory.create(:project, :repository => repository) }
  let(:repository) { Factory.create(:repository, :url => "git@git.squareup.com:square/web.git")}

  context "with a ruby build" do
    let!(:build_part) { Factory.create(:build_part, :build_instance => build, :options => {"language" => "ruby", "rvm" => "1.9.3-p194"}) }
    it "returns the rvm info" do
      build_metadata_header(build).should == "Ruby Version"
      build_part_field_value(build, build_part).should == "1.9.3-p194"
    end
  end

  context "with a build only having one target" do
    let!(:build_part) { Factory.create(:build_part, :build_instance => build, :paths => ['a']) }
    it "returns the rvm info" do
      build_metadata_header(build).should == "Target"
      build_part_field_value(build, build_part).should == "a"
    end
  end

  context "with a build having no metadata" do
    let!(:build_part) { Factory.create(:build_part, :build_instance => build, :paths => ['a', 'b']) }
    it "returns the rvm info" do
      build_metadata_header(build).should == nil
    end
  end
end
