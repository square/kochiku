require 'spec_helper'

describe Build do
  let(:project) { FactoryGirl.create(:big_rails_project) }
  let(:build) { FactoryGirl.create(:build, :project => project) }
  let(:parts) { [{'type' => 'cucumber', 'files' => ['a', 'b'], 'queue' => 'ci'}, {'type' => 'rspec', 'files' => ['c', 'd'], 'queue' => 'ci'}] }

  describe "#test_command" do
    before do
      project.repository.update_attributes!(:command_flag => "-Dsquareup.fastTestsOnly")
    end
    it "does not append a custom flag" do
      build.target_name = "foo"
      command = build.test_command(["foo"])
      command.should_not include("-Dsquareup.fastTestsOnly")
    end
    it "a custom arg is appended" do
      build.target_name = nil
      command = build.test_command(["foo"])
      command.should include("-Dsquareup.fastTestsOnly")
    end
  end

  describe "validations" do
    it "requires a ref to be set" do
      build.ref = nil
      build.should_not be_valid
      build.should have(1).error_on(:ref)
    end

    it "requires a project_id to be set" do
      build.project_id = nil
      build.should_not be_valid
      build.should have(1).error_on(:project_id)
    end

    it "should force uniqueness on project_id and ref pairs" do
      build2 = FactoryGirl.build(:build, :project => project, :ref => build.ref)
      build2.should_not be_valid
      build2.should have(1).error_on(:ref)
    end
  end

  describe "#partition" do
    it "should create a BuildPart for each path" do
      build.partition(parts)
      build.build_parts.map(&:kind).should =~ ['cucumber', 'rspec']
      build.build_parts.map(&:queue).should =~ [:ci, :ci]
      build.build_parts.find_by_kind('cucumber').paths.should =~ ['a', 'b']
    end

    it "should change state to running" do
      build.partition(parts)
      build.state.should == :running
    end

    it "creates parts with options" do
      build.partition([{"type" => "cucumber", "files" => ['a'], 'queue' => 'developer', 'options' => {"ruby" => "ree", "language" => 'ruby'}}])
      build_part = build.build_parts.first
      build_part.reload
      build_part.options.should == {"ruby" => "ree", "language" => 'ruby'}
    end

    it "should set the queue" do
      build.partition([{"type" => "cucumber", "files" => ['a'], 'queue' => 'developer'}])
      build_part = build.build_parts.first
      build_part.queue.should == :developer
    end

    it "should set the retry_count" do
      build.partition([{"type" => "cucumber", "files" => ['a'], 'queue' => 'developer', 'retry_count' => 3}])
      build_part = build.build_parts.first
      build_part.retry_count.should == 3
    end

    it "should create build attempts for each build part" do
      build.partition(parts)
      build.build_parts.all {|bp| bp.build_attempts.should have(1).item }
    end

    it "should enqueue build part jobs" do
      BuildAttemptJob.should_receive(:enqueue_on).twice
      build.partition(parts)
    end

    it "rolls back any changes to the database if an error occurs" do
      # set parts to an illegal value
      parts = [{'type' => 'rspec', 'files' => [], 'queue' => 'ci'}]

      build.build_parts.should be_empty
      build.state.should == :partitioning

      expect { build.partition(parts) }.to raise_error

      build.build_parts(true).should be_empty
      build.state.should == :runnable
    end
  end

  describe "#completed?" do
    Build::TERMINAL_STATES.each do |state|
      it "should be true for #{state}" do
        build.state = state
        build.should be_completed
      end
    end

    (Build::STATES - Build::TERMINAL_STATES).each do |state|
      it "should be false for #{state}" do
        build.state = state
        build.should_not be_completed
      end
    end
  end

  describe "#update_state_from_parts!" do
    let(:parts) { [{'type' => 'cucumber', 'files' => ['a'], 'queue' => 'ci', 'retry_count' => 0},
                   {'type' => 'rspec', 'files' => ['b'], 'queue' => 'ci', 'retry_count' => 0}] }
    before do
      stub_request(:post, /https:\/\/git\.squareup\.com\/api\/v3\/repos\/square\/kochiku\/statuses\//)
      build.stub(:running!)
      build.partition(parts)
      build.state.should == :runnable
    end

    it "should set a build state to running if it is successful so far, but still incomplete" do
      build.build_parts[0].last_attempt.finish!(:passed)
      build.update_state_from_parts!

      build.state.should == :running
    end

    it "should set build state to errored if any of its parts errored" do
      build.build_parts[0].last_attempt.finish!(:errored)
      build.build_parts[1].last_attempt.finish!(:passed)
      build.update_state_from_parts!

      build.state.should == :errored
    end

    it "should set build state to succeeded all of its parts passed" do
      build.build_parts[0].last_attempt.finish!(:passed)
      build.build_parts[1].last_attempt.finish!(:passed)
      build.update_state_from_parts!

      build.state.should == :succeeded
    end

    it "should set a build state to doomed if it has a failed part but is still has more parts to process" do
      build.build_parts[0].last_attempt.finish!(:failed)
      build.update_state_from_parts!
      build.state.should == :doomed
    end

    it "should change a doomed build to failed once it is complete" do
      build.build_parts[0].last_attempt.finish!(:failed)
      build.update_state_from_parts!
      build.state.should == :doomed

      build.build_parts[1].last_attempt.finish!(:passed)
      build.update_state_from_parts!
      build.state.should == :failed
    end

    it "should set build_state to running when a failed attempt is retried" do
      build.build_parts[0].last_attempt.finish!(:passed)
      build.build_parts[1].last_attempt.finish!(:failed)
      build.build_parts[1].build_attempts.create!(:state => :running)
      build.update_state_from_parts!

      build.state.should == :running
    end

    it "should set build_state to doomed when an attempt is retried but other attempts are failed" do
      build.build_parts[0].last_attempt.finish!(:failed)
      build.build_parts[1].last_attempt.finish!(:failed)
      build.build_parts[1].build_attempts.create!(:state => :running)
      build.update_state_from_parts!

      build.state.should == :doomed
    end

    it "should ignore the old build_attempts" do
      build.build_parts[0].last_attempt.finish!(:passed)
      build.build_parts[1].last_attempt.finish!(:errored)
      build.build_parts[1].build_attempts.create!(:state => :passed)
      build.update_state_from_parts!

      build.state.should == :succeeded
    end

    it "should not ignore old build_attempts that passed" do
      build.build_parts[0].last_attempt.finish!(:passed)
      build.build_parts[1].last_attempt.finish!(:passed)
      build.build_parts[1].build_attempts.create!(:state => :errored)
      build.update_state_from_parts!

      build.state.should == :succeeded
    end
  end

  describe "#elapsed_time" do
    it "returns the difference between the build creation time and the last finished time" do
      build.partition(parts)
      build.elapsed_time.should be_nil
      last_attempt = BuildAttempt.find(build.build_attempts.last.id)
      last_attempt.update_attributes(:finished_at => build.created_at + 10.minutes)
      build.elapsed_time.should be_within(1.second).of(10.minutes)
    end
  end

  describe "#abort!" do
    let(:build) { FactoryGirl.create(:build, :state => :runnable) }

    it "should mark the build as aborted" do
      expect{ build.abort! }.to change(build, :state).from(:runnable).to(:aborted)
    end

    it "should mark all of the build's unstarted build_attempts as aborted" do
      build_part1 = FactoryGirl.create(:build_part, :build_instance => build)
      build_part2 = FactoryGirl.create(:build_part, :build_instance => build)
      build_attempt_started = FactoryGirl.create(:build_attempt, :build_part => build_part1, :state => :running)
      build_attempt_unstarted = FactoryGirl.create(:build_attempt, :build_part => build_part2, :state => :runnable)
      build.abort!

      build_attempt_started.reload.state.should == :running
      build_attempt_unstarted.reload.state.should == :aborted
    end
  end

  describe '#to_png' do
    let(:build)     { FactoryGirl.create(:build, :state => state) }
    let(:png)       { build.to_png }
    let(:png_color) { png.get_pixel(png.width/2, png.height/2) }

    let(:red)   { 4151209727 }
    let(:green) { 3019337471 }
    let(:blue)  { 1856370687 }

    context 'with succeeded state' do
      let(:state) { :succeeded }

      it 'returns a green status png' do
        png_color.should == green
      end
    end

    %w(failed errored aborted doomed).each do |current_state|
      context "with #{current_state} state" do
        let(:state) { current_state }

        it 'returns a red status png' do
          png_color.should == red
        end
      end
    end

    %w(partitioning runnable running).each do |current_state|
      context "with #{current_state} state" do
        let(:state) { current_state }

        it 'returns a blue status png' do
          png_color.should == blue
        end
      end
    end
  end

  describe "#previous_successful_build" do
    let(:successful_build) {
      build.partition(parts)
      build.build_parts.each { |part| part.last_attempt.finish!(:passed) }
      build.update_state_from_parts!
      build.update_attribute(:updated_at, 1.minute.ago)
      build
    }

    it "returns nil when there are no previous successful builds for the project" do
      build.succeeded?.should be_false
      build2 = FactoryGirl.create(:build, :project => project)

      build.previous_successful_build.should be_nil
      build2.previous_successful_build.should be_nil
    end

    it "returns the most recent build in state == :succeeded prior to this build" do
      stub_request(:post, /https:\/\/git\.squareup\.com\/api\/v3\/repos\/square\/kochiku\/statuses\//)
      successful_build.succeeded?.should be_true
      build2 = FactoryGirl.create(:build, :project => project)
      build2.previous_successful_build.should == successful_build
    end
  end

  describe "#mergable_by_kochiku??" do
    before do
      build.project.main?.should be_false
      build.repository.allows_kochiku_merges.should be_true
    end

    context "when merge_on_success_enabled? is true" do
      before do
        build.update_attributes!(merge_on_success: true)
        build.merge_on_success_enabled?.should be_true
      end

      it "is true if it is a passed build" do
        build.state = :succeeded
        build.mergable_by_kochiku?.should be_true
      end

      it "is false if it is a failed build" do
        (Build::TERMINAL_STATES - [:succeeded]).each do |failed_state|
          build.state = failed_state
          build.mergable_by_kochiku?.should be_false
        end
      end
    end

    context "with merge_on_success disabled" do
      it "should never be true" do
        build.merge_on_success = false
        build.state = :succeeded

        build.mergable_by_kochiku?.should be_false
      end
    end

    context "when allows_kochiku_merges has been disabled on the repository" do
      before do
        build.repository.update_attributes(:allows_kochiku_merges => false)
      end

      it "should never be true" do
        build.merge_on_success = true
        build.state = :succeeded

        build.mergable_by_kochiku?.should be_false
      end
    end
  end

  describe "#merge_on_success_enabled?" do
    it "is true if it is a developer build with merge_on_success enabled" do
      build.merge_on_success = true
      build.merge_on_success_enabled?.should be_true
    end

    it "is false if it is a developer build with merge_on_success disabled" do
      build.merge_on_success = false
      build.merge_on_success_enabled?.should be_false
    end

    context "for a build on the main project" do
      let(:build) { FactoryGirl.create(:main_project_build) }

      it "is false if it is a main build" do
        build.merge_on_success = true
        build.merge_on_success_enabled?.should be_false
      end
    end
  end

  describe "#branch_or_ref" do
    it "returns the ref when there is no branch" do
      Build.new(:branch => nil, :ref => "ref").branch_or_ref.should == "ref"
      Build.new(:branch => "", :ref => "ref").branch_or_ref.should == "ref"
    end

    it "returns the ref when there is no branch" do
      Build.new(:branch => "some-branch", :ref => "ref").branch_or_ref.should == "some-branch"
    end
  end

  context "send_build_status_email!" do
    let(:project) { FactoryGirl.create(:big_rails_project, :repository => repository, :name => name) }
    let(:repository) { FactoryGirl.create(:repository)}
    let(:build) { FactoryGirl.create(:build, :state => :runnable, :project => project) }
    let(:name) { repository.repository_name + "_pull_requests" }
    let(:current_repo_master) { build.ref }
    let(:name) { repository.repository_name }
    let(:build_attempt) { build.build_parts.first.build_attempts.create!(:state => :failed) }

    it "should not send a failure email if the project has never had a successful build" do
      BuildMailer.should_not_receive(:build_break_email)
      build.send_build_status_email!
    end

    context "for a build that has had a successful build" do
      let(:build) { FactoryGirl.create(:build, :state => :succeeded, :project => project); FactoryGirl.create(:build, :state => :runnable, :project => project) }

      it "should not send the email if the build is not completed" do
        BuildMailer.should_not_receive(:build_break_email)
        build.send_build_status_email!
      end

      it "should not send the email if the build passed" do
        build.update_attribute(:state, :succeeded)
        BuildMailer.should_not_receive(:build_break_email)
        build.send_build_status_email!
      end

      it "should only send the build failure email once" do
        build.update_attribute(:state, :failed)
        BuildMailer.should_receive(:build_break_email).once.and_return(OpenStruct.new(:deliver => nil))
        build.send_build_status_email!
        build.send_build_status_email!
      end

      it "should send a fail email when the build is finished" do
        build.update_attribute(:state, :failed)
        BuildMailer.should_receive(:build_break_email).and_return(OpenStruct.new(:deliver => nil))
        build.send_build_status_email!
      end

      it "does not send a email if the project setting is disabled" do
        build.update_attribute(:state, :failed)
        repository.update_attributes!(:send_build_failure_email => false)
        build.reload
        BuildMailer.should_not_receive(:build_break_email)
        build.send_build_status_email!
      end

      context "for a build of a project not on master" do
        let(:project) { FactoryGirl.create(:project, :branch => "other-branch")}

        it "should not send a failure email" do
          BuildMailer.should_not_receive(:build_break_email)
          build.send_build_status_email!
        end
      end
    end
  end
end
