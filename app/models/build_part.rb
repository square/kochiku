class BuildPart < ActiveRecord::Base
  has_many :build_part_results
  belongs_to :build
  after_commit :enqueue_build_part_job
  validates_presence_of :kind, :paths

  serialize :paths, Array

  scope :failed, joins(:build_part_results).merge(BuildPartResult.failed)
  scope :passed, joins(:build_part_results).merge(BuildPartResult.passed)

  def enqueue_build_part_job
    BuildPartJob.enqueue_on(build.queue, id)
  end

  def status
    passed = build_part_results.passed.count
    if 0 == passed && 0 == build_part_results.failed.count
      :runnable
    elsif passed > 0
      :passed
    else
      :failed
    end
  end
end
