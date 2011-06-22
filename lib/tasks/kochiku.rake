namespace :kochiku do
  namespace :slave do
    task :start do
      ENV['QUEUES'] ||= "*"
      Rake::Task['resque:work'].invoke
    end
  end
end