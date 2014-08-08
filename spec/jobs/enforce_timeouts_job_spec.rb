require 'spec_helper'

describe EnforceTimeoutsJob do
  let(:repository) { FactoryGirl.create(:repository, :url => 'git@github.com:square/test-repo.git', :timeout => 10) }
  let(:project) { FactoryGirl.create(:big_rails_project, :repository => repository, :name => name) }
  let(:build) { FactoryGirl.create(:build, :state => :runnable, :project => project) }
  let(:build_part) { FactoryGirl.create(:build_part, :build_instance => build, :kind => :cucumber, :paths => ['baz'], :queue => :ci) }
  let(:name) { repository.name + '_pull_requests' }

  subject { EnforceTimeoutsJob.perform }

  it 'mark timed-out builds as errored' do
    attempt1 = BuildAttempt.create(:build_part_id => build_part.id, :started_at => 30.minutes.ago,
                                   :state => :running, :builder => 'test-worker')
    attempt2 = BuildAttempt.create(:build_part_id => build_part.id, :started_at => 10.minutes.ago,
                                   :state => :running, :builder => 'test-worker')
    subject
    expect(attempt1.reload.state).to be(:errored)
    expect(attempt2.reload.state).to be(:running)
  end
end
