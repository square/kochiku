namespace :kochiku do
  namespace :slave do
    desc 'Start a Build worker'
    task :start do
      ENV['QUEUES'] ||= "*"
      ENV['VVERBOSE'] ||= "1" if Rails.env.development?
      Rake::Task['resque:work'].invoke
    end

    desc "Setup a development environment to run a kochiku worker. Use capistrano for remote hosts"
    task :setup do
      tmp_dir = Rails.root.join('tmp', 'build-partition', 'web-cache')
      log_dir = Rails.root.join("log")

      unless File.exists?(tmp_dir)
        FileUtils.mkdir_p tmp_dir
        `git clone --recurse-submodules git@git.squareup.com:square/web.git #{tmp_dir}`
      end

      FileUtils.mkdir_p(log_dir)
    end
  end
end
