module ActiveWorkers
  def self.ec2
    puts Resque.workers.map {|w|
      hostname = w.to_s.split(':').first
      hostname =~ /ec2/ ? hostname : nil
    }.compact
  end

  def self.all
    puts Resque.workers.map {|w|
      w.to_s.split(':').first
    }
  end
end
