require 'spec_helper'

describe Build do
  let(:project) { FactoryGirl.create(:big_rails_project) }
  let(:build) { FactoryGirl.create(:build, :project => project) }
  let(:parts) { [{'type' => 'cucumber', 'files' => ['a', 'b'], 'queue' => 'ci'}, {'type' => 'rspec', 'files' => ['c', 'd'], 'queue' => 'ci'}] }

  describe "validations" do
    it "requires a ref to be set" do
      build.ref = nil
      expect(build).not_to be_valid
      expect(build).to have(1).error_on(:ref)
    end

    it "requires a project_id to be set" do
      build.project_id = nil
      expect(build).not_to be_valid
      expect(build).to have(1).error_on(:project_id)
    end

    it "should force uniqueness on ref" do
      build2 = FactoryGirl.build(:build, :project => project, :ref => build.ref)
      expect(build2).not_to be_valid
      expect(build2).to have(1).error_on(:ref)
    end
  end

  describe "#partition" do
    it "should create a BuildPart for each path" do
      build.partition(parts)
      expect(build.build_parts.map(&:kind)).to match_array(['cucumber', 'rspec'])
      expect(build.build_parts.map(&:queue)).to match_array([:ci, :ci])
      expect(build.build_parts.find_by_kind('cucumber').paths).to match_array(['a', 'b'])
    end

    it "should change state to running" do
      build.partition(parts)
      expect(build.state).to eq(:running)
    end

    it "creates parts with options" do
      build.partition([{"type" => "cucumber", "files" => ['a'], 'queue' => 'developer', 'options' => {"ruby" => "ree", "language" => 'ruby'}}])
      build_part = build.build_parts.first
      build_part.reload
      expect(build_part.options).to eq({"ruby" => "ree", "language" => 'ruby'})
    end

    it "should set the queue" do
      build.partition([{"type" => "cucumber", "files" => ['a'], 'queue' => 'developer'}])
      build_part = build.build_parts.first
      expect(build_part.queue).to eq(:developer)
    end

    it "should set the retry_count" do
      build.partition([{"type" => "cucumber", "files" => ['a'], 'queue' => 'developer', 'retry_count' => 3}])
      build_part = build.build_parts.first
      expect(build_part.retry_count).to eq(3)
    end

    it "should create build attempts for each build part" do
      build.partition(parts)
      build.build_parts.all? {|bp| expect(bp.build_attempts).to have(1).item }
    end

    it "should enqueue build part jobs" do
      expect(BuildAttemptJob).to receive(:enqueue_on).twice
      build.partition(parts)
    end

    it "rolls back any changes to the database if an error occurs" do
      # set parts to an illegal value
      parts = [{'type' => 'rspec', 'files' => [], 'queue' => 'ci'}]

      expect(build.build_parts).to be_empty
      expect(build.state).to eq(:partitioning)

      expect { build.partition(parts) }.to raise_error

      expect(build.build_parts(true)).to be_empty
      expect(build.state).to eq(:runnable)
    end
  end

  describe "#completed?" do
    Build::TERMINAL_STATES.each do |state|
      it "should be true for #{state}" do
        build.state = state
        expect(build).to be_completed
      end
    end

    (Build::STATES - Build::TERMINAL_STATES).each do |state|
      it "should be false for #{state}" do
        build.state = state
        expect(build).not_to be_completed
      end
    end
  end

  describe "#update_state_from_parts!" do
    let(:build) { FactoryGirl.create(:build, :project => project, :state => :running) }
    let!(:build_part_1) { FactoryGirl.create(:build_part, :build_instance => build) }
    let!(:build_part_2) { FactoryGirl.create(:build_part, :build_instance => build) }

    it "should set a build state to running if it is successful so far, but still incomplete" do
      FactoryGirl.create(:build_attempt, build_part: build_part_1, state: :passed)
      FactoryGirl.create(:build_attempt, build_part: build_part_2, state: :running)
      build.update_state_from_parts!

      expect(build.state).to eq(:running)
    end

    it "should set build state to errored if any of its parts errored" do
      FactoryGirl.create(:build_attempt, build_part: build_part_1, state: :errored)
      FactoryGirl.create(:build_attempt, build_part: build_part_2, state: :passed)
      build.update_state_from_parts!

      expect(build.state).to eq(:errored)
    end

    it "should set build state to succeeded if all of its parts passed" do
      FactoryGirl.create(:build_attempt, build_part: build_part_1, state: :passed)
      FactoryGirl.create(:build_attempt, build_part: build_part_2, state: :passed)
      build.update_state_from_parts!

      expect(build.state).to eq(:succeeded)
    end

    it "should set a build state to doomed if it has a failed part but is still has more parts to process" do
      FactoryGirl.create(:build_attempt, build_part: build_part_1, state: :failed)
      build.update_state_from_parts!
      expect(build.state).to eq(:doomed)
    end

    it "should change a doomed build to failed once it is complete" do
      ba1 = FactoryGirl.create(:build_attempt, build_part: build_part_1, state: :failed)
      ba2 = FactoryGirl.create(:build_attempt, build_part: build_part_2, state: :running)
      build.update_state_from_parts!
      expect(build.state).to eq(:doomed)

      ba2.update_attributes!(state: :passed)
      build.update_state_from_parts!
      expect(build.state).to eq(:failed)
    end

    it "should set build_state to running when a failed attempt is retried" do
      ba1 = FactoryGirl.create(:build_attempt, build_part: build_part_1, state: :passed)
      ba2_1 = FactoryGirl.create(:build_attempt, build_part: build_part_2, state: :failed)
      ba2_2 = FactoryGirl.create(:build_attempt, build_part: build_part_2, state: :running)
      build.update_state_from_parts!

      expect(build.state).to eq(:running)
    end

    it "should set build_state to doomed when an attempt is retried but other attempts are failed" do
      ba1 = FactoryGirl.create(:build_attempt, build_part: build_part_1, state: :failed)
      ba2_1 = FactoryGirl.create(:build_attempt, build_part: build_part_2, state: :failed)
      ba2_2 = FactoryGirl.create(:build_attempt, build_part: build_part_2, state: :running)
      build.update_state_from_parts!

      expect(build.state).to eq(:doomed)
    end

    it "should ignore the old build_attempts" do
      ba1 = FactoryGirl.create(:build_attempt, build_part: build_part_1, state: :passed)
      ba2_1 = FactoryGirl.create(:build_attempt, build_part: build_part_2, state: :errored)
      ba2_2 = FactoryGirl.create(:build_attempt, build_part: build_part_2, state: :passed)
      build.update_state_from_parts!

      expect(build.state).to eq(:succeeded)
    end

    it "should not ignore old build_attempts that passed" do
      ba1 = FactoryGirl.create(:build_attempt, build_part: build_part_1, state: :passed)
      ba2_1 = FactoryGirl.create(:build_attempt, build_part: build_part_2, state: :passed)
      ba2_2 = FactoryGirl.create(:build_attempt, build_part: build_part_2, state: :errored)
      build.update_state_from_parts!

      expect(build.state).to eq(:succeeded)
    end
  end

  describe "#elapsed_time" do
    it "returns the difference between the build creation time and the last finished time" do
      build.partition(parts)
      expect(build.elapsed_time).to be_nil
      last_attempt = BuildAttempt.find(build.build_attempts.last.id)
      last_attempt.update_attributes(:finished_at => build.created_at + 10.minutes)
      expect(build.elapsed_time).to be_within(1.second).of(10.minutes)
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

      expect(build_attempt_started.reload.state).to eq(:running)
      expect(build_attempt_unstarted.reload.state).to eq(:aborted)
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
        expect(png_color).to eq(green)
      end
    end

    %w(failed errored aborted doomed).each do |current_state|
      context "with #{current_state} state" do
        let(:state) { current_state }

        it 'returns a red status png' do
          expect(png_color).to eq(red)
        end
      end
    end

    %w(partitioning runnable running).each do |current_state|
      context "with #{current_state} state" do
        let(:state) { current_state }

        it 'returns a blue status png' do
          expect(png_color).to eq(blue)
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
      expect(build.succeeded?).to be false
      build2 = FactoryGirl.create(:build, :project => project)

      expect(build.previous_successful_build).to be_nil
      expect(build2.previous_successful_build).to be_nil
    end

    it "returns the most recent build in state == :succeeded prior to this build" do
      stub_request(:post, /https:\/\/git\.squareup\.com\/api\/v3\/repos\/square\/kochiku\/statuses\//)
      expect(successful_build.succeeded?).to be true
      build2 = FactoryGirl.create(:build, :project => project)
      expect(build2.previous_successful_build).to eq(successful_build)
    end
  end

  describe "#mergable_by_kochiku??" do
    before do
      expect(build.project.main?).to be false
      expect(build.repository.allows_kochiku_merges).to be true
    end

    context "when merge_on_success_enabled? is true" do
      before do
        build.update_attributes!(merge_on_success: true)
        expect(build.merge_on_success_enabled?).to be true
      end

      it "is true if it is a passed build" do
        build.state = :succeeded
        expect(build.mergable_by_kochiku?).to be true
      end

      it "is false if it is a failed build" do
        (Build::TERMINAL_STATES - [:succeeded]).each do |failed_state|
          build.state = failed_state
          expect(build.mergable_by_kochiku?).to be false
        end
      end
    end

    context "with merge_on_success disabled" do
      it "should never be true" do
        build.merge_on_success = false
        build.state = :succeeded

        expect(build.mergable_by_kochiku?).to be false
      end
    end

    context "when allows_kochiku_merges has been disabled on the repository" do
      before do
        build.repository.update_attributes(:allows_kochiku_merges => false)
      end

      it "should never be true" do
        build.merge_on_success = true
        build.state = :succeeded

        expect(build.mergable_by_kochiku?).to be false
      end
    end
  end

  describe "#merge_on_success_enabled?" do
    it "is true if it is a developer build with merge_on_success enabled" do
      build.merge_on_success = true
      expect(build.merge_on_success_enabled?).to be true
    end

    it "is false if it is a developer build with merge_on_success disabled" do
      build.merge_on_success = false
      expect(build.merge_on_success_enabled?).to be false
    end

    context "for a build on the main project" do
      let(:build) { FactoryGirl.create(:main_project_build) }

      it "is false if it is a main build" do
        build.merge_on_success = true
        expect(build.merge_on_success_enabled?).to be false
      end
    end
  end

  describe "#branch_or_ref" do
    it "returns the ref when there is no branch" do
      expect(Build.new(:branch => nil, :ref => "ref").branch_or_ref).to eq("ref")
      expect(Build.new(:branch => "", :ref => "ref").branch_or_ref).to eq("ref")
    end

    it "returns the ref when there is no branch" do
      expect(Build.new(:branch => "some-branch", :ref => "ref").branch_or_ref).to eq("some-branch")
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
      expect(BuildMailer).not_to receive(:build_break_email)
      build.send_build_status_email!
    end

    context "for a build that has had a successful build" do
      let(:build) { FactoryGirl.create(:build, :state => :succeeded, :project => project); FactoryGirl.create(:build, :state => :runnable, :project => project) }

      it "should not send the email if the build is not completed" do
        expect(BuildMailer).not_to receive(:build_break_email)
        build.send_build_status_email!
      end

      it "should not send the email if the build passed" do
        build.update_attribute(:state, :succeeded)
        expect(BuildMailer).not_to receive(:build_break_email)
        build.send_build_status_email!
      end

      it "should only send the build failure email once" do
        build.update_attribute(:state, :failed)
        expect(BuildMailer).to receive(:build_break_email).once.and_return(OpenStruct.new(:deliver => nil))
        build.send_build_status_email!
        build.send_build_status_email!
      end

      it "should send a fail email when the build is finished" do
        build.update_attribute(:state, :failed)
        expect(BuildMailer).to receive(:build_break_email).and_return(OpenStruct.new(:deliver => nil))
        build.send_build_status_email!
      end

      it "does not send a email if the project setting is disabled" do
        build.update_attribute(:state, :failed)
        repository.update_attributes!(:send_build_failure_email => false)
        build.reload
        expect(BuildMailer).not_to receive(:build_break_email)
        build.send_build_status_email!
      end

      context "for a build of a project not on master" do
        let(:project) { FactoryGirl.create(:project, :branch => "other-branch")}

        it "should not send a failure email" do
          expect(BuildMailer).not_to receive(:build_break_email)
          build.send_build_status_email!
        end
      end
    end
  end
end
