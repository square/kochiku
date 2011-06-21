class Build < ActiveRecord::Base
  has_many :build_parts
  has_many :build_part_results, :through => :build_parts
  symbolize :state, :in => [:preparing]#, runnable, enqueued, failed, succeeded
  symbolize :queue


  def started_at
    build_part_results.all.sort_by(&:started_at).first.started_at
  end

  def finished_at
#    build_part_results.all.sort_by(&:finished_at).last
  end

end
