require 'spec_helper'

describe BuildAttemptJob do
  let(:project) { FactoryGirl.create(:big_rails_project) }
  let(:build) { FactoryGirl.create(:build, :state => :partitioning, :project => project) }

  let(:build_part) { FactoryGirl.create(:build_part, :build_instance => build) }
  let(:build_attempt) { build_part.build_attempts.create!(:state => :runnable) }
  subject { BuildAttemptJob.new(build_attempt.id) }

  describe "#perform" do
    before do
      subject.stub(:tests_green? => true)
      GitRepo.stub(:run!)
    end

    it "sets the builder on its build attempt" do
      hostname = "i-am-a-compooter"
      subject.stub(:tests_green?)
      subject.stub(:hostname => hostname)

      subject.perform
      build_attempt.reload.builder.should == hostname
    end

    context "build is successful" do
      before { subject.stub(:tests_green? => true) }

      it "creates a build result with a passed result" do
        expect { subject.perform }.to change{build_attempt.reload.state}.from(:runnable).to(:passed)
      end
    end

    context "build is unsuccessful" do
      before { subject.stub(:tests_green? => false) }

      it "creates a build result with a failed result" do
        expect { subject.perform }.to change{build_attempt.reload.state}.from(:runnable).to(:failed)
      end
    end
  end

  describe "#collect_artifacts" do
    let(:master_host) { "http://" + Rails.application.config.master_host }
    before do
      Cocaine::CommandLine.unstub!(:new)    # it is desired that the gzip command to go through
      stub_request(:any, /#{master_host}.*/)
    end

    it "posts the artifacts back to the master server" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          wanted_logs = ['a.wantedlog', 'b.wantedlog', 'd/c.wantedlog']

          FileUtils.mkdir 'd'
          (wanted_logs + ['e.unwantedlog']).each do |file_path|
            File.open(file_path, 'w') do |file|
              file.puts "Carrierwave won't save blank files"
            end
          end

          subject.collect_artifacts('**/*.wantedlog')

          wanted_logs.each do |artifact|
            log_name = File.basename(artifact)
            WebMock.should have_requested(:post, master_host + "/build_attempts/#{build_attempt.to_param}/build_artifacts").with { |req| req.body.include?(log_name) }
          end
        end
      end
    end

    it "should not attempt to save blank files" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          log_name = 'empty.log'
          system("touch #{log_name}")
          subject.collect_artifacts('*.log')
          WebMock.should_not have_requested(:post, master_host + "/build_attempts/#{build_attempt.to_param}/build_artifacts").with { |req| req.body.include?(log_name) }
        end
      end
    end
  end
end
