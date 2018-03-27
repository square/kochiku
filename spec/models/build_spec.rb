require 'spec_helper'

describe Build do
  let(:branch) { FactoryGirl.create(:branch) }
  let(:build) { FactoryGirl.create(:build, branch_record: branch) }
  let(:parts) { [{'type' => 'cucumber', 'files' => ['a', 'b'], 'queue' => 'ci'}, {'type' => 'rspec', 'files' => ['c', 'd'], 'queue' => 'ci'}] }

  before do
    allow(GitRepo).to receive(:load_kochiku_yml).and_return(nil)
  end

  describe "validations" do
    it "requires a ref to be set" do
      build.ref = nil
      expect(build).not_to be_valid
      expect(build).to have(1).error_on(:ref)
    end

    it "requires a branch_id to be set" do
      build.branch_id = nil
      expect(build).not_to be_valid
      expect(build).to have(1).error_on(:branch_id)
    end

    it "should force uniqueness on ref" do
      build2 = FactoryGirl.build(:build, branch_record: branch, ref: build.ref)
      expect(build2).not_to be_valid
      expect(build2).to have(1).error_on(:ref)
    end
  end

  describe '#kochiku_yml' do
    it 'only tries to load once if it fails' do
      expect(GitRepo).to receive(:load_kochiku_yml).once
      5.times do
        build.kochiku_yml
      end
    end
  end

  describe "#partition" do
    it "should create a BuildPart for each path" do
      build.partition(parts)
      expect(build.build_parts.map(&:kind)).to match_array(['cucumber', 'rspec'])
      expect(build.build_parts.map(&:queue)).to match_array(['ci', 'ci'])
      expect(build.build_parts.find_by_kind('cucumber').paths).to match_array(['a', 'b'])
    end

    it "should change state to runnable" do
      expect {
        build.partition(parts)
      }.to change(build, :state).from('partitioning').to('runnable')
    end

    it "creates parts with options" do
      build.partition([{"type" => "cucumber", "files" => ['a'], 'queue' => 'developer', 'options' => {"ruby" => "ree"}}])
      build_part = build.build_parts.first
      build_part.reload
      expect(build_part.options).to eq({"ruby" => "ree"})
    end

    it "should set the queue" do
      build.partition([{"type" => "cucumber", "files" => ['a'], 'queue' => 'developer'}])
      build_part = build.build_parts.first
      expect(build_part.queue).to eq('developer')
    end

    it "should set the retry_count" do
      build.partition([{"type" => "cucumber", "files" => ['a'], 'queue' => 'developer', 'retry_count' => 3}])
      build_part = build.build_parts.first
      expect(build_part.retry_count).to eq(3)
    end

    it "should create build attempts for each build part" do
      build.partition(parts)
      build.build_parts.all? { |bp| expect(bp.build_attempts).to have(1).item }
    end

    it "should enqueue build part jobs if repository is enabled" do
      expect(BuildAttemptJob).to receive(:enqueue_on).twice
      build.partition(parts)
    end

    it "should not enqueue build part jobs if repository is disabled" do
      build2 = FactoryGirl.create(:build_on_disabled_repo)
      build2.partition(parts)
      expect(BuildAttemptJob).to receive(:enqueue_on).exactly(0).times
      expect(build2.build_parts(true)).to be_empty
    end

    it "rolls back any changes to the database if an error occurs" do
      # set parts to an illegal value
      parts = [{'type' => 'rspec', 'files' => [], 'queue' => 'ci'}]

      expect(build.build_parts).to be_empty
      expect(build.state).to eq('partitioning')

      expect { build.partition(parts) }.to raise_error(ActiveRecord::ActiveRecordError)

      expect(build.build_parts(true)).to be_empty
      expect(build.state).to eq('runnable')
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
    let(:build) { FactoryGirl.create(:build, branch_record: branch, :state => 'running') }
    let!(:build_part_1) { FactoryGirl.create(:build_part, :build_instance => build) }
    let!(:build_part_2) { FactoryGirl.create(:build_part, :build_instance => build) }

    it "should set a build state to running if it is successful so far, but still incomplete" do
      FactoryGirl.create(:build_attempt, build_part: build_part_1, state: 'passed')
      FactoryGirl.create(:build_attempt, build_part: build_part_2, state: 'running')
      build.update_state_from_parts!

      expect(build.state).to eq('running')
    end

    it "should set build state to errored if any of its parts errored" do
      FactoryGirl.create(:build_attempt, build_part: build_part_1, state: 'errored')
      FactoryGirl.create(:build_attempt, build_part: build_part_2, state: 'passed')
      build.update_state_from_parts!

      expect(build.state).to eq('errored')
    end

    it "should set build state to succeeded if all of its parts passed" do
      FactoryGirl.create(:build_attempt, build_part: build_part_1, state: 'passed')
      FactoryGirl.create(:build_attempt, build_part: build_part_2, state: 'passed')
      build.update_state_from_parts!

      expect(build.state).to eq('succeeded')
    end

    it "should set a build state to doomed if it has a failed part but is still has more parts to process" do
      FactoryGirl.create(:build_attempt, build_part: build_part_1, state: 'failed')
      build.update_state_from_parts!
      expect(build.state).to eq('doomed')
    end

    it "should change a doomed build to failed once it is complete" do
      ba1 = FactoryGirl.create(:build_attempt, build_part: build_part_1, state: 'failed')
      ba2 = FactoryGirl.create(:build_attempt, build_part: build_part_2, state: 'running')
      build.update_state_from_parts!
      expect(build.state).to eq('doomed')

      ba2.update!(state: 'passed')
      build.update_state_from_parts!
      expect(build.state).to eq('failed')
    end

    it "should set build_state to running when a failed attempt is retried" do
      ba1 = FactoryGirl.create(:build_attempt, build_part: build_part_1, state: 'passed')
      ba2_1 = FactoryGirl.create(:build_attempt, build_part: build_part_2, state: 'failed')
      ba2_2 = FactoryGirl.create(:build_attempt, build_part: build_part_2, state: 'running')
      build.update_state_from_parts!

      expect(build.state).to eq('running')
    end

    it "should set build_state to doomed when an attempt is retried but other attempts are failed" do
      ba1 = FactoryGirl.create(:build_attempt, build_part: build_part_1, state: 'failed')
      ba2_1 = FactoryGirl.create(:build_attempt, build_part: build_part_2, state: 'failed')
      ba2_2 = FactoryGirl.create(:build_attempt, build_part: build_part_2, state: 'running')
      build.update_state_from_parts!

      expect(build.state).to eq('doomed')
    end

    it "should ignore the old build_attempts" do
      ba1 = FactoryGirl.create(:build_attempt, build_part: build_part_1, state: 'passed')
      ba2_1 = FactoryGirl.create(:build_attempt, build_part: build_part_2, state: 'errored')
      ba2_2 = FactoryGirl.create(:build_attempt, build_part: build_part_2, state: 'passed')
      build.update_state_from_parts!

      expect(build.state).to eq('succeeded')
    end

    it "should not ignore old build_attempts that passed" do
      ba1 = FactoryGirl.create(:build_attempt, build_part: build_part_1, state: 'passed')
      ba2_1 = FactoryGirl.create(:build_attempt, build_part: build_part_2, state: 'passed')
      ba2_2 = FactoryGirl.create(:build_attempt, build_part: build_part_2, state: 'errored')
      build.update_state_from_parts!

      expect(build.state).to eq('succeeded')
    end

    context "when the build is aborted" do
      let(:build) { FactoryGirl.create(:build, branch_record: branch, state: 'aborted') }

      it "should set state to succeeded if a build is aborted, but all of its parts passed" do
        # scenario is applicable if a build is aborted only after its build parts are already running
        FactoryGirl.create(:build_attempt, build_part: build_part_1, state: 'passed')
        FactoryGirl.create(:build_attempt, build_part: build_part_2, state: 'passed')
        build.update_state_from_parts!

        expect(build.state).to eq('succeeded')
      end

      it "should remain aborted when build attempts finish as errored or failed" do
        FactoryGirl.create(:build_attempt, build_part: build_part_1, state: 'passed')
        ba = FactoryGirl.create(:build_attempt, build_part: build_part_1, state: 'errored')
        build.update_state_from_parts!
        expect(build.state).to eq('aborted')

        ba.update_attributes!(state: 'failed')
        build.update_state_from_parts!
        expect(build.state).to eq('aborted')
      end
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
    let(:build) { FactoryGirl.create(:build, :state => 'runnable', :merge_on_success => true) }

    it "should mark the build as aborted" do
      expect{ build.abort! }.to change(build, :state).from('runnable').to('aborted')
    end

    it "should strip a true merge_on_success setting" do
      expect{ build.abort! }.to change(build, :merge_on_success).to(false)
    end

    it "should mark all of the build's unstarted build_attempts as aborted" do
      build_part1 = FactoryGirl.create(:build_part, :build_instance => build)
      build_part2 = FactoryGirl.create(:build_part, :build_instance => build)
      build_attempt_started = FactoryGirl.create(:build_attempt, :build_part => build_part1, :state => 'running')
      build_attempt_unstarted = FactoryGirl.create(:build_attempt, :build_part => build_part2, :state => 'runnable')
      build.abort!

      expect(build_attempt_started.reload.state).to eq('running')
      expect(build_attempt_unstarted.reload.state).to eq('aborted')
    end
  end

  describe '#to_png' do
    let(:build)     { FactoryGirl.create(:build, :state => state) }
    let(:png)       { build.to_png }
    let(:png_color) { png.get_pixel(png.width / 2, png.height / 2) }

    let(:red)   { 4151209727 }
    let(:green) { 3019337471 }
    let(:blue)  { 1856370687 }

    context 'with succeeded state' do
      let(:state) { 'succeeded' }

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
      build.build_parts.each { |part| part.last_attempt.finish!('passed') }
      build.update_state_from_parts!
      build.update_attribute(:updated_at, 1.minute.ago)
      build
    }

    it "returns nil when there are no previous successful builds for the branch" do
      expect(build.succeeded?).to be false
      build2 = FactoryGirl.create(:build, branch_record: branch)

      expect(build.previous_successful_build).to be_nil
      expect(build2.previous_successful_build).to be_nil
    end

    it "returns the most recent build in state == 'succeeded' prior to this build" do
      stub_request(:post, /https:\/\/git\.squareup\.com\/api\/v3\/repos\/square\/kochiku\/statuses\//)
      expect(successful_build.succeeded?).to be true
      build2 = FactoryGirl.create(:build, branch_record: branch)
      expect(build2.previous_successful_build).to eq(successful_build)
    end
  end

  describe "#mergable_by_kochiku??" do
    let(:build) { FactoryGirl.create(:build, branch_record: branch) }

    before do
      expect(build.branch_record).to_not be_convergence
      expect(build.repository.allows_kochiku_merges).to be true
    end

    context "when merge_on_success_enabled? is true" do
      before do
        build.update_attributes!(merge_on_success: true)
        expect(build.merge_on_success_enabled?).to be true
      end

      it "is true if it is a passed build" do
        build.state = 'succeeded'
        expect(build.mergable_by_kochiku?).to be true
      end

      it "is false if it is a failed build" do
        (Build::TERMINAL_STATES - ['succeeded']).each do |failed_state|
          build.state = failed_state
          expect(build.mergable_by_kochiku?).to be false
        end
      end
    end

    context "with merge_on_success disabled" do
      it "should never be true" do
        build.merge_on_success = false
        build.state = 'succeeded'

        expect(build.mergable_by_kochiku?).to be false
      end
    end

    context "when allows_kochiku_merges has been disabled on the repository" do
      before do
        build.repository.update_attributes(:allows_kochiku_merges => false)
      end

      it "should never be true" do
        build.merge_on_success = true
        build.state = 'succeeded'

        expect(build.mergable_by_kochiku?).to be false
      end
    end

    context 'there is a newer build for the same branch' do
      let(:build) {
        FactoryGirl.create(:build, branch_record: branch,
                                   state: 'succeeded', merge_on_success: true)
      }

      before do
        expect(build.mergable_by_kochiku?).to be true
      end

      it 'should no longer be mergable' do
        expect(build).to receive(:newer_branch_build_exists?).and_return(true)
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

    context "for a build on a convergence branch" do
      let(:build) { FactoryGirl.create(:convergence_branch_build) }

      it "should be false" do
        build.merge_on_success = true
        expect(build.merge_on_success_enabled?).to be false
      end
    end
  end

  describe "#newer_branch_build_exists?" do
    before do
      @build1 = FactoryGirl.create(:build, branch_record: branch)
      @build2 = FactoryGirl.create(:build, branch_record: branch)
    end

    it "should be true for the earlier build" do
      expect(@build1.newer_branch_build_exists?).to be true
    end

    it "should be false for the later build" do
      expect(@build2.newer_branch_build_exists?).to be false
    end
  end

  describe "#already_failed?" do
    let!(:build_part_1) { FactoryGirl.create(:build_part, :build_instance => build, :retry_count => 3) }
    it "returns false when there exists successful build attempt" do
      ba1 = FactoryGirl.create(:build_attempt, build_part: build_part_1, state: 'failed')
      ba2_1 = FactoryGirl.create(:build_attempt, build_part: build_part_1, state: 'passed')
      expect(build.already_failed?).to eq(false)
    end

    it "returns true when there exists no successful build attempt" do
      ba1 = FactoryGirl.create(:build_attempt, build_part: build_part_1, state: 'failed')
      ba2_1 = FactoryGirl.create(:build_attempt, build_part: build_part_1, state: 'running')
      expect(build.already_failed?).to eq(true)
    end
  end

  describe "#send_build_status_email!" do
    let(:repository) { FactoryGirl.create(:repository) }
    let(:branch) { FactoryGirl.create(:branch, repository: repository) }
    let(:build) { FactoryGirl.create(:build, state: 'runnable', branch_record: branch) }
    let(:build_attempt) { build.build_parts.first.build_attempts.create!(state: 'failed') }

    it "should not send a failure email if the branch has never had a successful build" do
      expect(BuildMailer).not_to receive(:build_break_email)
      build.send_build_status_email!
    end

    context "for a branch that has had a successful build" do
      let(:build) {
        FactoryGirl.create(:build, state: 'succeeded', branch_record: branch)
        FactoryGirl.create(:build, state: 'runnable', branch_record: branch)
      }

      it "should not send the email if the build is not completed" do
        expect(BuildMailer).not_to receive(:build_break_email)
        build.send_build_status_email!
      end

      it "should not send the failure email if the build passed" do
        build.update_attribute(:state, 'succeeded')
        expect(BuildMailer).not_to receive(:build_break_email)
        expect(BuildMailer).to receive(:build_success_email).and_return(OpenStruct.new(:deliver => nil))
        build.send_build_status_email!
      end

      it "should only send the build failure email once" do
        build.update_attribute(:state, 'failed')
        expect(BuildMailer).to receive(:build_break_email).once.and_return(OpenStruct.new(:deliver => nil))
        build.send_build_status_email!
        build.send_build_status_email!
      end

      it "should send a fail email when the build is finished" do
        build.update_attribute(:state, 'failed')
        expect(BuildMailer).to receive(:build_break_email).and_return(OpenStruct.new(:deliver => nil))
        build.send_build_status_email!
      end

      it "does not send a email if the repository setting is disabled" do
        build.update_attribute(:state, 'failed')
        repository.update_attributes!(:send_build_failure_email => false)
        build.reload
        expect(BuildMailer).not_to receive(:build_break_email)
        build.send_build_status_email!
      end

      context "when email_on_first_failure is false" do
        before do
          repository.update_attribute(:email_on_first_failure, false)
        end
        it "should not send email on first build part failure" do
          build.update_attribute(:state, 'doomed')
          expect(BuildMailer).to_not receive(:build_break_email)
          build.send_build_status_email!
        end

        context "retries enabled" do
          let!(:build_part_1) { FactoryGirl.create(:build_part, :build_instance => build, :retry_count => 3) }
          let!(:build_part_2) { FactoryGirl.create(:build_part, :build_instance => build, :retry_count => 3) }

          it "should not send email before retry" do
            ba1 = FactoryGirl.create(:build_attempt, build_part: build_part_1, state: 'running')
            ba2_1 = FactoryGirl.create(:build_attempt, build_part: build_part_2, state: 'running')

            expect(BuildMailer).to_not receive(:build_break_email)

            ba2_1.finish!('failed')
          end
        end
      end

      context "when email_on_first_failure is true" do
        before do
          repository.update_attribute(:email_on_first_failure, true)
        end

        context "on a convergence branch build" do
          let(:branch) { FactoryGirl.create(:convergence_branch, repository: repository) }
          let!(:build_part_1) { FactoryGirl.create(:build_part, :build_instance => build, :retry_count => 3) }
          let!(:build_part_2) { FactoryGirl.create(:build_part, :build_instance => build, :retry_count => 3) }

          it "should not send email prior to retry" do
            ba1 = FactoryGirl.create(:build_attempt, build_part: build_part_1, state: 'passed')
            ba2_1 = FactoryGirl.create(:build_attempt, build_part: build_part_2, state: 'running')

            expect(BuildMailer).to_not receive(:build_break_email)

            ba2_1.finish!('failed')
          end
        end

        context "branch build" do
          let(:branch) { FactoryGirl.create(:branch, repository: repository) }
          let(:branch_build) { FactoryGirl.create(:build, :state => 'runnable', :branch_record => branch) }
          let!(:build_part_1) { FactoryGirl.create(:build_part, :build_instance => branch_build, :retry_count => 3) }
          let!(:build_part_2) { FactoryGirl.create(:build_part, :build_instance => branch_build, :retry_count => 3) }

          it "should send email prior to retry" do
            ba1 = FactoryGirl.create(:build_attempt, build_part: build_part_1, state: 'passed')
            ba2_1 = FactoryGirl.create(:build_attempt, build_part: build_part_2, state: 'running')

            expect(BuildMailer).to receive(:build_break_email).once.and_return(OpenStruct.new(:deliver => nil))

            ba2_1.finish!('failed')
          end
        end
      end

      context "for a build not on a convergence branch" do
        before do
          expect(branch).to_not be_convergence
        end

        it "should not send a failure email" do
          expect(BuildMailer).not_to receive(:build_break_email)
          build.send_build_status_email!
        end

        it "should send a success email" do
          build.update_attribute(:state, 'succeeded')
          expect(BuildMailer).to receive(:build_success_email).and_return(OpenStruct.new(:deliver => nil))
          build.send_build_status_email!
        end
      end
    end
  end

  describe '#as_json' do
    it 'returns a hash with elapsed_time' do
      build.partition(parts)
      hash = build.as_json
      expect(hash['build'].key?('elapsed_time')).to eq(true)
      expect(hash['build']['elapsed_time']).to eq(build.elapsed_time)
      last_attempt = BuildAttempt.find(build.build_attempts.last.id)
      last_attempt.update_attributes(:finished_at => build.created_at + 10.minutes)
      hash = build.as_json
      expect(hash['build'].key?('elapsed_time')).to eq(true)
      expect(hash['build']['elapsed_time']).to eq(build.elapsed_time)
    end

    it 'returns a hash with out test_command' do
      build.partition(parts)
      hash = build.as_json
      expect(hash['build'].key?('test_command')).to eq(false)
    end

    it 'returns elapsed_time even when other options are used' do
      build.partition(parts)
      hash = build.as_json(include: :build_parts)
      expect(hash['build'].key?('elapsed_time')).to eq(true)
    end

    it 'allows overriding :methods option' do
      build.partition(parts)
      hash = build.as_json(methods: :idle_time)
      expect(hash['build'].key?('elapsed_time')).to eq(false)
      expect(hash['build'].key?('idle_time')).to eq(true)
    end
  end
end
