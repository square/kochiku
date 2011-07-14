$:.unshift(File.expand_path('./lib', ENV['rvm_path'])) # Add RVM's lib directory to the load path.
require "rvm/capistrano"
set :rvm_type, :user
set :rvm_ruby_string, 'ree@kochiku'

require 'bundler/capistrano' # bundler bootstrap

set :application, "Kochiku"
set :repository,  "git@git.squareup.com:square/kochiku.git"
set :branch, "master"
set :scm, :git
set :scm_command, '/usr/local/bin/git'

set :user, "square"
set :deploy_to, "/Users/square/kochiku"
set :deploy_via, :remote_cache
set :use_sudo, false

server "macbuild-master.sfo", :app, :web, :db, :primary => true
role :worker, "macbuild24.sfo", "macbuild25.sfo", "macbuild26.sfo"

set :rails_env,      "production"

namespace :deploy do
  task :start, :roles => :app, :except => { :no_release => true } do
    run "cd #{current_path} && rails server thin -e #{rails_env} -p 3000 -d"
  end

  task :stop, :roles => :app, :except => { :no_release => true } do
    @pid = nil
    run("cd #{current_path} && cat tmp/pids/server.pid") do |channel, stream, data|
      @pid = data if stream == :out
    end
    run "kill #{@pid}"
  end

  task :restart, :roles => :app, :except => { :no_release => true } do
    stop
    start
  end
end

namespace :workers do
  task :update, :roles => :worker do
    run <<-CMD
      cd ~/Development/kochiku &&\
      #{scm_command} fetch origin &&\
      #{scm_command} reset --hard origin/#{branch} &&\
      bundle --deployment --quiet --without development test &&\
      launchctl stop com.squareup.kochiku-slave
    CMD
  end
end
