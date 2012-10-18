require 'spec_helper'

describe Build do
  let(:project) { FactoryGirl.create(:big_rails_project) }
  let(:build) { FactoryGirl.create(:build, :project => project, :queue => "developer") }
  let(:parts) { [{'type' => 'cucumber', 'files' => ['a', 'b']}, {'type' => 'rspec', 'files' => ['c', 'd']}] }

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
    it "requires a queue to be set" do
      build.queue = nil
      build.should_not be_valid
      build.should have(1).error_on(:queue)
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
      build.build_parts.find_by_kind('cucumber').paths.should =~ ['a', 'b']
    end

    it "should change state to runnable" do
      build.partition(parts)
      build.state.should == :runnable
    end

    it "creates parts with options" do
      build.partition([{"type" => "cucumber", "files" => ['a'], 'options' => {"rvm" => "ree", "language" => 'ruby'}}])
      build_part = build.build_parts.first
      build_part.reload
      build_part.options.should == {"rvm" => "ree", "language" => 'ruby'}
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
      parts = [{'type' => 'rspec', 'files' => []}]

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
    let(:parts) { [{'type' => 'cucumber', 'files' => ['a']}, {'type' => 'rspec', 'files' => ['b']}] }
    before do
      stub_request(:post, /https:\/\/git\.squareup\.com\/api\/v3\/repos\/square\/kochiku\/statuses\//)
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

    it "updates github when a build passes" do
      states = []
      stub_request(:post, "https://git.squareup.com/api/v3/repos/square/kochiku/statuses/#{build.ref}").with do |request|
        request.headers["Authorization"].should == "token #{GithubRequest::OAUTH_TOKEN}"
        body = JSON.parse(request.body)
        states << body["state"]
        true
      end
      build.build_parts[0].last_attempt.finish!(:passed)
      build.update_state_from_parts!
      build.build_parts[1].last_attempt.finish!(:passed)
      build.update_state_from_parts!
      states.should == ["pending", "success"]
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

    it "should ignore the old build_attempts" do
      build.build_parts[0].last_attempt.finish!(:passed)
      build.build_parts[1].last_attempt.finish!(:errored)
      build.build_parts[1].build_attempts.create!(:state => :passed)
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
    let(:build) { FactoryGirl.create(:build, :state => :runnable, :queue => :developer) }

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

    let(:red)   { 4284901119 }
    let(:green) { 1728014079 }
    let(:blue)  { 1718026239 }

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

  describe "#auto_mergable?" do
    context "with auto merge enabled" do
      before do
        build.stub(auto_merge_enabled?: true)
      end

      it "is true if it is a passed build" do
        build.state = :succeeded
        build.auto_mergable?.should be_true
      end

      it "is false if it is a failed build" do
        (Build::TERMINAL_STATES - [:succeeded]).each do |failed_state|
          build.state = failed_state
          build.auto_mergable?.should be_false
        end
      end
    end

    it "is false if it is a passed build with auto merge disabled" do
      build.stub(auto_merge_enabled?: false)
      build.state = :succeeded
      build.auto_mergable?.should be_false
    end
  end

  describe "#auto_merge_enabled?" do
    it "is true if it is a developer build with auto_merge" do
      build.queue = :developer
      build.auto_merge = true
      build.auto_merge_enabled?.should be_true
    end

    it "is false if it is a developer build without auto_merge" do
      build.queue = :developer
      build.auto_merge = false
      build.auto_merge_enabled?.should be_false
    end

    it "is false if it is a ci build" do
      build.queue = :ci
      build.auto_merge = true
      build.auto_merge_enabled?.should be_false
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
end
