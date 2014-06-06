require 'spec_helper'

describe AutosizeWorkersJob do
  let(:thresholds) {
    Settings.worker_thresholds
  }
  let(:sample_count) {
    thresholds[:number_of_samples]
  }
  let(:maximum_workers) {
    thresholds[:maximum_total_workers]
  }
  let(:minimum_workers) {
    thresholds[:minimum_total_workers]
  }

  let(:idle_response) {
    {
        :workers=>maximum_workers - 30,
        :working=>maximum_workers - 100,
    }
  }
  let(:busy_response) {
    {
        :workers=>maximum_workers - 30,
        :working=>maximum_workers - 35,
    }
  }
  let(:small_pool) {
    {
        :workers=>minimum_workers + 5,
        :working=>0,
    }
  }
  let(:full_pool) {
    {
        :workers=>maximum_workers,
        :working=>maximum_workers - 5,
    }
  }

  let(:redis_connection) { Redis.new }

  subject { AutosizeWorkersJob.perform }

  def push(count, response)
    redis_connection.del(MonitorWorkersJob.REDIS_STATS_KEY)
    1.upto(count) do
      redis_connection.rpush(MonitorWorkersJob.REDIS_STATS_KEY, response.to_json)
    end
  end

  context "When the pool is mostly idle" do
    describe "#perform" do
      it "does nothing if not sufficient stats" do
        push(sample_count - 2, idle_response)
        expect(Resque).to_not receive(:info)
        expect(AutosizeWorkersJob).to_not receive(:adjust_worker_count)
        subject
      end

      it "Shrinks the pool if idle for sufficient time" do
        push(sample_count, idle_response)
        allow(Resque).to receive(:info).and_return(idle_response)
        expect(AutosizeWorkersJob).to receive(:adjust_worker_count).with(-10)
        subject
      end

      it "never shrinks the pool below minimum size" do
        push(sample_count, small_pool)
        allow(Resque).to receive(:info).and_return(small_pool)
        expect(AutosizeWorkersJob).to receive(:adjust_worker_count).with(-5)
        subject
      end

      it "Does not adjust size if even one sample shows busy" do
        push(sample_count - 1, small_pool)
        small_pool[:working] = small_pool[:workers]
        redis_connection.rpush(MonitorWorkersJob.REDIS_STATS_KEY, small_pool.to_json)
        allow(Resque).to receive(:info).and_return(small_pool)
        expect(AutosizeWorkersJob).to_not receive(:adjust_worker_count)
        subject
      end
    end
  end

  context "When the pool is very busy" do
    it "Expands the pool if busy for sufficient time" do
      push(sample_count, busy_response)
      allow(Resque).to receive(:info).and_return(busy_response)
      expect(AutosizeWorkersJob).to receive(:adjust_worker_count).with(thresholds[:instance_chunk_size])
      subject
    end

    it "Does not expand the pool if already fully expanded" do
      push(sample_count, full_pool)
      allow(Resque).to receive(:info).and_return(full_pool)
      expect(AutosizeWorkersJob).to_not receive(:adjust_worker_count)
      subject
    end

    it "Does not expand the pool if not busy enough" do
      busy_response[:working] = busy_response[:workers] - thresholds[:idle_insufficient_count] - 1
      push(sample_count, busy_response)
      allow(Resque).to receive(:info).and_return(busy_response)
      expect(AutosizeWorkersJob).to_not receive(:adjust_worker_count)
      subject
    end

    it "Does not expand the pool if worker count has changed" do
      push(sample_count, busy_response)
      busy_response[:workers] -= 1
      allow(Resque).to receive(:info).and_return(busy_response)
      expect(AutosizeWorkersJob).to_not receive(:adjust_worker_count)
      subject
    end
  end

  context "When settings are not present" do
    it "Does nothing" do
      allow(Settings).to receive(:worker_thresholds).and_return(nil)
      subject
    end
  end

  describe '.adjust_worker_count' do
    it 'with a negative amount it enqueues ShutdownInstanceJobs' do
      expect(Resque).to receive(:enqueue_to).with(a_string, 'ShutdownInstanceJob').exactly(5).times
      expect(Cocaine::CommandLine).to_not receive(:new)
      AutosizeWorkersJob.adjust_worker_count(-5)
    end

    it 'with a positive amount it executes spin up script' do
      expect(Resque).to_not receive(:enqueue_to)
      expect(Cocaine::CommandLine).to receive(:new).with(a_string, "5").and_return(double(:run => nil))
      AutosizeWorkersJob.adjust_worker_count(5)
    end
  end
end
