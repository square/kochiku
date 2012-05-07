require "rvm/capistrano"
set :rvm_type, :user
set :rvm_ruby_string, 'ruby-1.9.3-p194@kochiku'

require 'bundler/capistrano' # adds bundle:install step to deploy pipeline

default_run_options[:env] = {'PATH' => '/usr/local/bin:$PATH'}

set :application, "Kochiku"
set :repository,  "git@git.squareup.com:square/kochiku.git"
set :branch, "master"
set :scm, :git
set :scm_command, 'git'

set :user, "square"
set :deploy_to, "$HOME/kochiku"
set :deploy_via, :remote_cache
set :keep_releases, 5
set :use_sudo, false

server "macbuild-master.sfo.squareup.com", :app, :web, :db, :worker, :primary => true

set :rails_env, "production"

after "deploy:setup", "kochiku:setup"
after "deploy:create_symlink", "kochiku:symlinks"

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

  desc "Restart the build workers"
  task :restart_workers, :roles => :worker do
    # the trailing semicolons are required because this is passed to the shell as a single string
    run <<-CMD
      resque1_pid=$(cat #{shared_path}/pids/resque1.pid);
      resque2_pid=$(cat #{shared_path}/pids/resque2.pid);
      kill -QUIT $resque1_pid;
      kill -QUIT $resque2_pid;

      while ps x | egrep -q "^($resque1_pid|$resque2_pid)"; do
        echo "Waiting for Resque workers to stop on $HOSTNAME...";
        sleep 5;
      done;
    CMD
  end
end

namespace :kochiku do
  task :setup, :roles => [:app, :worker] do
    run "rvm gemset create 'kochiku'"
    run "gem install bundler -v '~> 1.0.21' --conservative"
    run "mkdir -p #{shared_path}/{build-partition,log_files}"
    run "[ -d #{shared_path}/build-partition/web-cache ] || #{scm_command} clone --recursive git@git.squareup.com:square/web.git #{shared_path}/build-partition/web-cache"
  end

  task :symlinks, :roles => [:app, :worker] do
    run "ln -nfFs #{shared_path}/build-partition #{current_path}/tmp/build-partition"
    run "ln -nfFs #{shared_path}/log_files #{current_path}/public/log_files"
  end

  task :cleanup_zombies, :roles => [:worker] do
    run "ps -eo 'pid ppid comm' |grep -i resque |grep Paused | awk '$2 == 1 { print $1 }' | xargs kill"
  end
end
