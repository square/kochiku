require 'spec_helper'

describe BuildPart do
  let(:repository) { FactoryGirl.create(:repository) }
  let(:project) { FactoryGirl.create(:project, :repository => repository) }
  let(:build) { FactoryGirl.create(:build, :queue => :ci, :project => project) }
  let(:build_part) { FactoryGirl.create(:build_part, :paths => ["a", "b"], :kind => "spec", :build_instance => build) }

  describe "#create_and_enqueue_new_build_attempt!" do
    it "should create a new build attempt" do
      expect {
        build_part.create_and_enqueue_new_build_attempt!
      }.to change(build_part.build_attempts, :count).by(1)
    end

    it "enqueues a job to update the build state" do
      BuildStateUpdateJob.should_receive(:enqueue).with(build.id)
      build_part.create_and_enqueue_new_build_attempt!
    end

    it "enqueues onto a repository specific queue" do
      repository.update_attribute(:queue_override, "ci-osx")
      BuildAttemptJob.should_receive(:enqueue_on).once.with do |queue, arg_hash|
        queue.should == "ci-osx"
        true
      end
      build_part.create_and_enqueue_new_build_attempt!
    end

    # TODO: Please fix this code and delete this spec
    it "enqueues onto a different queue then square web" do
      BuildAttemptJob.should_receive(:enqueue_on).once.with do |queue, arg_hash|
        queue.should == "ci"
        true
      end
      build_part.create_and_enqueue_new_build_attempt!
    end

    it "should enqueue the build attempt for building" do
      repository.update_attributes!(:use_spec_and_ci_queues => true)
      build_part.update_attributes!(:options => {"ruby" => "ree"})
      # the queue name should include the queue name of the build instance and the type of the test file
      BuildAttemptJob.should_receive(:enqueue_on).once.with do |queue, arg_hash|
        queue.should == "ci-spec"
        arg_hash["build_attempt_id"].should_not be_blank
        arg_hash["build_ref"].should_not be_blank
        arg_hash["build_kind"].should_not be_blank
        arg_hash["test_files"].should_not be_blank
        arg_hash["repo_name"].should_not be_blank
        arg_hash["test_command"].should_not be_blank
        arg_hash["repo_url"].should_not be_blank
        arg_hash["options"].should == {"ruby" => "ree"}
        true
      end
      build_part.create_and_enqueue_new_build_attempt!
    end
  end

  describe "#unsuccessful?" do
    subject { build_part.unsuccessful? }

    context "with all successful attempts" do
      before do
        2.times { FactoryGirl.create(:build_attempt, :build_part => build_part, :state => :passed) }
      end

      it { should be_false }
    end

    context "with one successful attempt" do
      before {
        2.times { FactoryGirl.create(:build_attempt, :build_part => build_part, :state => :failed) }
        FactoryGirl.create(:build_attempt, :build_part => build_part, :state => :passed)
      }

      it { should be_false }
    end

    context "with all unsuccessful attempts" do
      before do
        2.times { FactoryGirl.create(:build_attempt, :build_part => build_part, :state => :failed) }
      end

      it { should be_true }
    end
  end

  describe "#status" do
    subject { build_part.status }

    context "with all successful attempts" do
      before do
        2.times { FactoryGirl.create(:build_attempt, :build_part => build_part, :state => :passed) }
      end

      it { should == :passed }
    end

    context "with one successful attempt" do
      before do
        FactoryGirl.create(:build_attempt, :build_part => build_part, :state => :failed)
        FactoryGirl.create(:build_attempt, :build_part => build_part, :state => :passed)
        FactoryGirl.create(:build_attempt, :build_part => build_part, :state => :failed)
      end

      it { should == :passed }
    end

    context "with no successful attempts" do
      before do
        FactoryGirl.create(:build_attempt, :build_part => build_part, :state => :failed)
        FactoryGirl.create(:build_attempt, :build_part => build_part, :state => :running)
      end

      it { should == :running }
    end
  end

  context "#is_for?" do
    it "is true for the same language" do
      build_part = BuildPart.new(:options => {"language" => "ruby"})
      build_part.is_for?(:ruby).should be_true
      build_part.is_for?("ruby").should be_true
      build_part.is_for?("RuBy").should be_true
    end

    it "is false for the different languages" do
      build_part = BuildPart.new(:options => {"language" => "python"})
      build_part.is_for?(:ruby).should be_false
    end
  end

  describe "#is_running?" do
    subject { build_part.is_running? }
    context "when not finished" do
      it { should be_true }
    end
    context "when finished" do
      before { FactoryGirl.create(:build_attempt, :build_part => build_part, :state => :passed, :finished_at => Time.now) }
      it { should be_false }
    end
  end

  context "#last_completed_attempt" do
    it "does not find if not in a completed state" do
      (BuildAttempt::STATES - BuildAttempt::COMPLETED_BUILD_STATES).each do |state|
        FactoryGirl.create(:build_attempt, :state => state)
      end
      BuildPart.last.last_completed_attempt.should be_nil
    end
    it "does find a completed" do
      attempt = FactoryGirl.create(:build_attempt, :state => :passed)
      BuildPart.last.last_completed_attempt.should == attempt
    end
  end

  describe "#last_stdout_artifact" do
    let(:artifact) { FactoryGirl.create(:build_artifact, :log_file => File.open(FIXTURE_PATH + file)) }
    let(:attempt) { artifact.build_attempt }
    let(:part) { attempt.build_part }

    subject { part.last_stdout_artifact }

    context "stdout.log" do
      let(:file) { "stdout.log" }
      it { should == artifact }
    end

    context "stdout.log.gz" do
      let(:file) { "stdout.log.gz" }
      it { should == artifact }
    end
  end

  describe "#last_junit_artifact" do
    let(:artifact) { FactoryGirl.create(:build_artifact, :log_file => File.open(FIXTURE_PATH + "rspec.xml.log.gz")) }
    let(:part) { artifact.build_attempt.build_part }

    subject { part.last_junit_artifact }

    it { should == artifact }

    describe "#last_junit_failures" do
      subject { part.last_junit_failures }

      it { should have(1).testcase }
    end
  end
end
