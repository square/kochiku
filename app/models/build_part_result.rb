class BuildPartResult < ActiveRecord::Base
  has_many :build_artifacts
  belongs_to :build_part

  symbolize :state, :in => [:passed, :failed, :error]

  scope :failed, where(:state => 'failed')
  scope :passed, where(:state => 'passed')

  def elapsed_time
    finished_at - started_at if finished_at && started_at
  end
end
