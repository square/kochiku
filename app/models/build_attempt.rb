class BuildAttempt < ActiveRecord::Base
  has_many :build_artifacts, :dependent => :destroy, :inverse_of => :build_attempt
  belongs_to :build_part, :inverse_of => :build_attempts

  STATES = [:runnable, :running, :passed, :failed, :errored, :aborted]
  symbolize :state, :in => STATES

  STATES.each do |state|
    scope state, where(:state => state.to_s)
  end

  def elapsed_time
    if finished_at && started_at
      finished_at - started_at
    elsif started_at
      Time.now - started_at
    else
      nil
    end
  end

  def start!(builder)
    update_attributes(:state => :running, :started_at => Time.now, :builder => builder)
  end

  def finish!(state)
    update_attributes!(:state => state, :finished_at => Time.now)
  end

  def error_occurred!
    finish!(:errored)
  end

  def unsuccessful?
    state == :failed || state == :errored
  end
end
