class Build < ActiveRecord::Base
  has_many :build_parts
  has_many :build_part_results, :through => :build_parts
  symbolize :state, :in => [:partitioning, :runnable, :running, :failed, :succeeded]
  symbolize :queue

  def partition(parts)
    parts.each do |part|
      build_parts.create!(:kind => part['type'], :paths => part['files'])
    end
  end

  def enqueue
    update_attribute(:state, :runnable)
    build_parts.each do |build_part|
      BuildPartJob.enqueue_in(queue, build_part.id)
    end
  end

  def started_at
    build_part_results.all.sort_by(&:started_at).first.started_at
  end

  def finished_at
#    build_part_results.all.sort_by(&:finished_at).last
  end

end
