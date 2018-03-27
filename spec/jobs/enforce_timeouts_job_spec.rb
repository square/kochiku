require 'spec_helper'

describe EnforceTimeoutsJob do
  let(:repo_timeout) { 10 } # minutes
  let(:repository) { FactoryGirl.create(:repository, :url => 'git@github.com:square/test-repo.git', :timeout => repo_timeout) }
  let(:branch) { FactoryGirl.create(:branch, :repository => repository) }
  let(:build) { FactoryGirl.create(:build, :state => 'runnable', :branch_record => branch) }
  let(:build_part) { FactoryGirl.create(:build_part, :build_instance => build, :kind => :cucumber, :paths => ['baz'], :queue => 'ci') }

  subject { EnforceTimeoutsJob.perform }

  before do
    # Stub needed to test rebuild feature
    allow(GitRepo).to receive(:load_kochiku_yml).and_return(nil)
  end

  it 'should mark timed-out builds as errored' do
    attempt1 = BuildAttempt.create(build_part_id: build_part.id, started_at: (repo_timeout + 7).minutes.ago,
                                   state: 'running', builder: 'test-worker')
    attempt2 = BuildAttempt.create(build_part_id: build_part.id, started_at: (repo_timeout + 2).minutes.ago,
                                   state: 'running', builder: 'test-worker')
    subject
    expect(attempt1.reload.state).to eq('errored')
    expect(attempt2.reload.state).to eq('running')
  end

  describe "automatic rebuilds" do
    before do
      @overdue_ba = BuildAttempt.create(build_part_id: build_part.id, started_at: (repo_timeout + 7).minutes.ago,
                                        state: 'running', builder: 'test-worker')
    end

    context "the aborted build attempt is the most recent attempt on the BuildPart" do
      it "should rebuild" do
        expect(build_part.build_attempts.last).to eq(@overdue_ba)

        subject
        build_part.reload
        expect(build_part.build_attempts.last).to_not eq(@overdue_ba)
      end
    end

    context "the aborted build attempt is not the most recent attempt on the BuildPart" do
      before do
        BuildAttempt.create(build_part_id: build_part.id, started_at: 2.minutes.ago,
                            state: 'running', builder: 'test-worker')
      end
      it "should not rebuild" do
        expect {
          subject
        }.to_not change { build_part.build_attempts.count }
      end
    end
  end
end
