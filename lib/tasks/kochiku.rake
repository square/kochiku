namespace :kochiku do
  namespace :slave do
    desc 'Start a Build worker'
    task :start do
        ENV['QUEUES'] ||= "*"
        ENV['VVERBOSE'] ||= "1" if Rails.env.development?
        Rake::Task['resque:work'].invoke
    end

    task :start_daemon do
      pid = fork
      if pid.nil?
        Process.daemon
        Rake::Task['kochiku:slave:start'].invoke
      else
        puts "started kochiku slave"
      end
    end
  end
end
