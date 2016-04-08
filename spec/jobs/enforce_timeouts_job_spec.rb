require 'spec_helper'

describe EnforceTimeoutsJob do
  let(:repo_timeout) { 10 } # minutes
  let(:repository) { FactoryGirl.create(:repository, :url => 'git@github.com:square/test-repo.git', :timeout => repo_timeout) }
  let(:branch) { FactoryGirl.create(:branch, :repository => repository) }
  let(:build) { FactoryGirl.create(:build, :state => :runnable, :branch_record => branch) }
  let(:build_part) { FactoryGirl.create(:build_part, :build_instance => build, :kind => :cucumber, :paths => ['baz'], :queue => :ci) }

  subject { EnforceTimeoutsJob.perform }

  it 'should mark timed-out builds as errored' do
    attempt1 = BuildAttempt.create(build_part_id: build_part.id, started_at: (repo_timeout + 7).minutes.ago,
                                   state: :running, builder: 'test-worker')
    attempt2 = BuildAttempt.create(build_part_id: build_part.id, started_at: (repo_timeout + 2).minutes.ago,
                                   state: :running, builder: 'test-worker')
    subject
    expect(attempt1.reload.state).to be(:errored)
    expect(attempt2.reload.state).to be(:running)
  end
end
