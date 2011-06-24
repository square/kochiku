class BuildPart < ActiveRecord::Base
  has_many :build_part_results
  belongs_to :build
  after_commit :enqueue_build_part_job
  validates_presence_of :kind, :paths

  serialize :paths, Array

  scope :failed, joins(:build_part_results).merge(BuildPartResult.failed)
  scope :passed, joins(:build_part_results).merge(BuildPartResult.passed)

  def enqueue_build_part_job
    build_part_result = build_part_results.create!(:state => :runnable)
    BuildPartJob.enqueue_on(build.queue, build_part_result.id)
  end

  def rebuild!
    enqueue_build_part_job
  end

  def status
    build_part_results.order(:created_at).last.state
  end
end
