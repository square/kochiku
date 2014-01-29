require 'spec_helper'

describe BuildPart do
  let(:repository) { FactoryGirl.create(:repository) }
  let(:project) { FactoryGirl.create(:project, :repository => repository) }
  let(:build) { FactoryGirl.create(:build, :project => project) }
  let(:build_part) { FactoryGirl.create(:build_part, :paths => ["a", "b"], :kind => "spec", :build_instance => build, :queue => 'ci') }

  describe "#create_and_enqueue_new_build_attempt!" do
    it "should create a new build attempt" do
      expect {
        build_part.create_and_enqueue_new_build_attempt!
      }.to change(build_part.build_attempts, :count).by(1)
    end

    it "updates the build state to running" do
      build.state.should_not == :running
      build_part.create_and_enqueue_new_build_attempt!
      build.state.should == :running
    end

    it "enqueues onto the queue specified in the build part" do
      build_part.update_attribute(:queue, 'queueX')
      BuildAttemptJob.should_receive(:enqueue_on).once.with do |queue, arg_hash|
        queue.should == "queueX"
        true
      end
      build_part.create_and_enqueue_new_build_attempt!
    end

    it "should enqueue the build attempt for building" do
      build_part.update_attributes!(:options => {"ruby" => "ree"})
      BuildAttemptJob.should_receive(:enqueue_on).once.with do |queue, arg_hash|
        queue.should == "ci"
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

  describe "#job_args" do
    let(:repository) { FactoryGirl.create(:repository, :url => "git@github.com:org/test-repo.git") }

    context "with a git mirror specified" do
      before do
        settings = SettingsAccessor.new(<<-YAML)
        git_servers:
          github.com:
            type: github
            mirror: "git://git-mirror.example.com/"
        YAML
        stub_const "Settings", settings
      end

      it "should substitute the mirror" do
        build_attempt = build_part.build_attempts.create!(:state => :runnable)
        args = build_part.job_args(build_attempt)
        args["repo_url"].should == "git://git-mirror.example.com/org/test-repo.git"
      end
    end

    context "with no git mirror specified" do
      before do
        settings = SettingsAccessor.new(<<-YAML)
        git_servers:
          github.com:
            type: github
        YAML
        stub_const "Settings", settings
      end

      it "should return the original git url" do
        build_attempt = build_part.build_attempts.create!(:state => :runnable)
        args = build_part.job_args(build_attempt)
        args["repo_url"].should == repository.url
      end
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

  describe "#should_reattempt?" do
    let(:build_part) { FactoryGirl.create(:build_part, retry_count: 1, build_instance: build) }

    context "for a main-branch build" do
      let(:project) { FactoryGirl.create(:main_project, repository: repository) }

      it "might reattempt" do
        expect(build_part.should_reattempt?).to be_true
      end
    end

    context "for a merge_on_success branch build" do
      let(:build) { FactoryGirl.create(:build, project: project, merge_on_success: true) }

      it "might reattempt" do
        expect(build_part.should_reattempt?).to be_true
      end
    end

    context "for a non merge_on_success branch build" do
      before { build.merge_on_success.should be_false }
      
      it "will not reattempt" do
        expect(build_part.should_reattempt?).to be_false
      end
    end

    context "when we have already hit the retry count" do
      let(:project) { FactoryGirl.create(:main_project, repository: repository) }

      before do
        FactoryGirl.create(:build_attempt, build_part: build_part, state: :failed)
        FactoryGirl.create(:build_attempt, build_part: build_part, state: :failed)
      end

      it "will not reattempt" do
        expect(build_part.should_reattempt?).to be_false
      end
    end

    context "when we are just one away from the retry count" do
      let(:project) { FactoryGirl.create(:main_project, repository: repository) }

      before do
        FactoryGirl.create(:build_attempt, build_part: build_part, state: :failed)
      end

      it "will reattempt" do
        expect(build_part.should_reattempt?).to be_true
      end
    end
  end
end
