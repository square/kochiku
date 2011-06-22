class BuildPart < ActiveRecord::Base
  has_many :build_part_results
  belongs_to :build
  after_create :enqueue_build_part_job

  serialize :paths, Array

  scope :failed, joins(:build_part_results).where('build_part_results.result = ?', 'failed')
  scope :passed, joins(:build_part_results).where('build_part_results.result = ?', 'passed')

  def enqueue_build_part_job
    BuildPartJob.enqueue_on(build.queue, id)
  end
end
