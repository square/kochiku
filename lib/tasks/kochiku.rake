require_relative '../active_workers.rb'

namespace :kochiku do
  task :workers do
    ActiveWorkers.all
  end

  task :ec2_workers  do
    ActiveWorkers.ec2
  end
end
