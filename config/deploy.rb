require 'bundler/capistrano' # adds bundle:install step to deploy pipeline

default_run_options[:env] = {'PATH' => '/usr/local/bin:$PATH'}

set :application, "Kochiku"
set :repository,  "https://github.com/square/kochiku.git"
set :branch, "master"
set :scm, :git
set :scm_command, 'git'

set :user, "kochiku"
set :deploy_to, "/app/#{user}/kochiku"
set :deploy_via, :remote_cache
set :keep_releases, 10
set :use_sudo, false

set :rails_env, "production"

after "deploy:setup",          "kochiku:setup"
after "deploy:create_symlink", "kochiku:symlinks"
before "deploy:finalize_update", "deploy:overwrite_database_yml"
after "deploy:update_code",    "deploy:migrate"
after "deploy:restart",        "deploy:cleanup"

namespace :deploy do
  task :start, :roles => :app do
    run "touch #{current_release}/tmp/restart.txt"
  end

  task :stop, :roles => :app do
    # Do nothing.
  end

  desc "Restart the web application server and all of the build workers"
  task :restart do
    restart_app
    restart_workers
  end

  desc "Restart the web application server"
  task :restart_app, :roles => :app do
    run "touch #{current_release}/tmp/restart.txt"
  end

  desc "Restart the resque workers"
  task :restart_workers, :roles => :worker do
    # the trailing semicolons are required because this is passed to the shell as a single string
    run <<-CMD
      resque1_pid=$(cat #{shared_path}/pids/resque1.pid||echo undefined);
      resque2_pid=$(cat #{shared_path}/pids/resque2.pid||echo undefined);
      resque3_pid=$(cat #{shared_path}/pids/resque3.pid||echo undefined);
      resque4_pid=$(cat #{shared_path}/pids/resque4.pid||echo undefined);
      resque_scheduler_pid=$(cat #{shared_path}/pids/resque-scheduler.pid||echo undefined);
      kill -QUIT $resque1_pid;
      kill -QUIT $resque2_pid;
      kill -QUIT $resque3_pid;
      kill -QUIT $resque4_pid;
      kill -QUIT $resque_scheduler_pid;
      while ps x | egrep -q "^($resque1_pid|$resque2_pid|$resque3_pid|$resque4_pid|$resque_scheduler_pid)"; do
        echo "Waiting for Resque workers to stop on $HOSTNAME...";
        sleep 5;
      done;
    CMD
  end

  task :overwrite_database_yml do
    top.upload("config/database.production.yml", "#{release_path}/config/database.yml")
  end
end

namespace :workers do
  task :list, :roles => :app do
    run "cd #{current_path}; rake kochiku:workers RAILS_ENV=production"
  end

  task :ec2, :roles => :app do
    run "cd #{current_path}; rake kochiku:ec2_workers RAILS_ENV=production"
  end
end

namespace :kochiku do
  task :setup, :roles => [:app, :worker] do
    run "gem install bundler -v '~> 1.3' --conservative"
    run "mkdir -p #{shared_path}/{build-partition,log_files}"
  end

  task :symlinks, :roles => [:app, :worker] do
    run "ln -nfFs #{shared_path}/build-partition #{current_path}/tmp/build-partition"
    run "ln -nfFs #{shared_path}/log_files #{current_path}/public/log_files"
  end

  task :cleanup_zombies, :roles => [:worker] do
    run "ps -eo 'pid ppid comm' |grep -i resque |grep Paused | awk '$2 == 1 { print $1 }' | xargs kill"
  end
end

# load installation specific capistrano config
load File.expand_path('deploy.custom.rb', File.dirname(__FILE__))

server kochiku_host, :app, :web, :db, :worker, :primary => true
