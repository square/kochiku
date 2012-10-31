module ActiveWorkers
  def self.ec2
    Resque.workers.map {|w|
      hostname = w.to_s.split(':').first
      hostname =~ /ec2/ ? hostname : nil
    }.compact.uniq
  end

  def self.all
    Resque.workers.map {|w|
      w.to_s.split(':').first
    }.uniq
  end
end
