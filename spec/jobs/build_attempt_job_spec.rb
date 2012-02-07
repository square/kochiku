require 'spec_helper'

describe BuildAttemptJob do
  let(:master_host) { "http://" + Rails.application.config.master_host }
  let(:project) { FactoryGirl.create(:big_rails_project) }
  let(:build) { FactoryGirl.create(:build, :state => :partitioning, :project => project) }

  let(:build_part) { FactoryGirl.create(:build_part, :build_instance => build) }
  let(:build_attempt) { build_part.build_attempts.create!(:state => :runnable) }
  subject { BuildAttemptJob.new(build_attempt.id, build_part.kind, build.ref, build_part.paths) }

  describe "#perform" do
    before do
      GitRepo.stub(:run!)
    end

    context "build_attempt has been aborted" do
      let(:build_attempt) { FactoryGirl.create(:build_attempt, :state => :aborted) }

      it "should return without running the tests" do
        stub_request(:post, "#{master_host}/build_attempts/#{build_attempt.id}/start").to_return(:body => {'build_attempt' => {'state' => 'aborted'}}.to_json)

        subject.should_not_receive(:run_tests)
        subject.perform
        build_attempt.reload.started_at.should be_nil
      end
    end

    it "sets the builder on its build attempt" do
      hostname = "i-am-a-compooter"
      subject.stub(:run_tests)
      subject.stub(:hostname => hostname)
      stub_request(:post, "#{master_host}/build_attempts/#{build_attempt.id}/start").to_return(:body => {'build_attempt' => {'state' => 'running'}}.to_json)
      stub_request(:post, "#{master_host}/build_attempts/#{build_attempt.id}/finish")

      subject.perform
      WebMock.should have_requested(:post, "#{master_host}/build_attempts/#{build_attempt.id}/start").with(:body => {"builder"=> hostname})
    end

    context "build is successful" do
      before { subject.stub(:run_tests => true) }

      it "creates a build result with a passed result" do
        stub_request(:post, "#{master_host}/build_attempts/#{build_attempt.id}/start").to_return(:body => {'build_attempt' => {'state' => 'running'}}.to_json)
        stub_request(:post, "#{master_host}/build_attempts/#{build_attempt.id}/finish")

        subject.perform

        WebMock.should have_requested(:post, "#{master_host}/build_attempts/#{build_attempt.id}/finish").with(:body => {"state"=> "passed"})
      end
    end

    context "build is unsuccessful" do
      before { subject.stub(:run_tests => false) }

      it "creates a build result with a failed result" do
        stub_request(:post, "#{master_host}/build_attempts/#{build_attempt.id}/start").to_return(:body => {'build_attempt' => {'state' => 'running'}}.to_json)
        stub_request(:post, "#{master_host}/build_attempts/#{build_attempt.id}/finish")

        subject.perform

        WebMock.should have_requested(:post, "#{master_host}/build_attempts/#{build_attempt.id}/finish").with(:body => {"state"=> "failed"})
      end
    end

    context "an exception occurs" do
      it "sets the build attempt state to errored" do
        stub_request(:post, "#{master_host}/build_attempts/#{build_attempt.id}/start").to_return(:body => {'build_attempt' => {'state' => 'running'}}.to_json)
        stub_request(:post, "#{master_host}/build_attempts/#{build_attempt.id}/finish")

        subject.should_receive(:run_tests).and_raise(StandardError)
        BuildAttemptJob.should_receive(:new).and_return(subject)

        expect { BuildAttemptJob.perform(build_attempt.id, build_part.kind, build.ref, build_part.paths) }.to raise_error(StandardError)

        WebMock.should have_requested(:post, "#{master_host}/build_attempts/#{build_attempt.id}/finish").with(:body => {"state"=> "errored"})
      end
    end
  end

  describe "#collect_artifacts" do
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
            WebMock.should have_requested(:post, "#{master_host}/build_attempts/#{build_attempt.to_param}/build_artifacts").with { |req| req.body.include?(log_name) }
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
          WebMock.should_not have_requested(:post, "#{master_host}/build_attempts/#{build_attempt.to_param}/build_artifacts").with { |req| req.body.include?(log_name) }
        end
      end
    end
  end
end
