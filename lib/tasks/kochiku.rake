require_relative '../active_workers.rb'

namespace :kochiku do
  task :workers => :environment do
    puts ActiveWorkers.all
  end

  task :ec2_workers => :environment  do
    puts ActiveWorkers.ec2
  end
end
