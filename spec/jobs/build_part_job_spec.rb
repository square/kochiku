require 'spec_helper'

describe BuildPartJob do
  let(:valid_attributes) do
    {
        :build => Build.build_sha!(:sha => sha, :queue => queue),
        :paths => ["a", "b"],
        :kind => "test",
    }
  end

  let(:sha) { "abcdef" }
  let(:queue) { "master" }
  let(:build_part) { BuildPart.create!(valid_attributes) }
  subject { BuildPartJob.new(build_part.id) }

  describe "#perform" do
    before do
      subject.stub(:tests_green? => true)
      GitRepo.stub(:run!)
    end

    context "build is successful" do
      before { subject.stub(:tests_green? => true) }

      it "creates a build result with a passed result" do
        expect { subject.perform }.to change(build_part.build_part_results, :count).by(1)
        build_part.build_part_results.last.state.should == :passed
      end
    end

    context "build is unsuccessful" do
      before { subject.stub(:tests_green? => false) }

      it "creates a build result with a failed result" do
        expect { subject.perform }.to change(build_part.build_part_results, :count).by(1)
        build_part.build_part_results.last.state.should == :failed
      end
    end
  end

  describe "#collect_artifacts" do
    it "stores specified artifacts to the database" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          wanted_logs = ['a.wantedlog', 'b.wantedlog', 'd/c.wantedlog']
          FileUtils.mkdir 'd'
          FileUtils.touch wanted_logs
          FileUtils.touch 'e.unwantedlog'
          result = build_part.build_part_results.create!(:state => :passed)
          subject.collect_artifacts(result, '**/*.wantedlog')

          result.build_artifacts.map(&:name).should =~ wanted_logs
        end
      end
    end
  end
end
