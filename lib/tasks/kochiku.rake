namespace :kochiku do
  namespace :slave do
    desc 'Start a Build worker'
    task :start do
      ENV['QUEUES'] ||= "*"
      ENV['VVERBOSE'] ||= "1" if Rails.env.development?
      Rake::Task['resque:work'].invoke
    end
  end
end
