require 'spec_helper'

describe 'When collecting stats' do

  it 'should collect a fixed number of stats' do
    # FIXME: fix this test so it does not create 1000 Redis connections
    1.upto(1000) do
      MonitorWorkersJob.perform
    end
    stats_length = Redis.new.llen(MonitorWorkersJob.REDIS_STATS_KEY)
    expect(stats_length).to eq(Settings.worker_thresholds[:number_of_samples])
  end
end
