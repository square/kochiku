require 'spec_helper'

describe ResqueQueueHelper do
  describe ".remove_enqueued_build_attempt_jobs" do
    before do
      Resque.redis.flushdb
    end

    def build_attempt_job_json(build_attempt_id)
      {
        "args" => [build_attempt_id],
        "class" => "BuildAttemptJob"
      }.to_json
    end

    it "should remove the unstarted build_attempts from the Resque queue" do
      build = FactoryGirl.create(:build, :state => :runnable, :queue => :developer)
      build_part = FactoryGirl.create(:build_part, :build_instance => build, :kind => :spec)
      build_attempt = FactoryGirl.create(:build_attempt, :build_part => build_part, :state => :runnable)
      Resque.redis.lpush("queue:#{build.queue}-spec", build_attempt_job_json(build_attempt.id))

      Resque.redis.lpush("queue:#{build.queue}-spec", build_attempt_job_json(9999))

      ResqueQueueHelper.remove_enqueued_build_attempt_jobs("#{build.queue}-spec", build.build_attempts.collect(&:id))
      Resque.redis.lrem("queue:#{build.queue}-spec", 0, build_attempt_job_json(build_attempt.id)).should == 0
      Resque.redis.llen("queue:#{build.queue}-spec").should == 1
    end
  end
end
