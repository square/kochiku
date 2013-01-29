require_relative '../active_workers'

namespace :kochiku do
  task :workers => :environment do
    puts ActiveWorkers.all.join ' '
  end

  task :ec2_workers => :environment  do
    puts ActiveWorkers.ec2.join ' '
  end
end
