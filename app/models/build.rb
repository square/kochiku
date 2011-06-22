class Build < ActiveRecord::Base
  has_many :build_parts
  has_many :build_part_results, :through => :build_parts
  symbolize :state, :in => [:partitioning, :runnable, :running, :failed, :succeeded, :error]
  symbolize :queue
  validates_presence_of :queue

  after_create :enqueue_partitioning_job

  def self.build_sha!(attributes)
    Build.create!(attributes.merge(:state => :partitioning))
  end

  def enqueue_partitioning_job
    Resque.enqueue(BuildPartitioningJob, self.id)
  end

  def partition(parts)
    transaction do
      update_attributes(:state => :runnable)
      parts.each { |part| build_parts.create!(:kind => part['type'], :paths => part['files']) }
    end
  end

  def started_at
    build_part_results.all.sort_by(&:started_at).first.started_at
  end

  def finished_at
#    build_part_results.all.sort_by(&:finished_at).last
  end
end
