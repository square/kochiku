#!/usr/bin/env bash

source "$HOME/.rvm/scripts/rvm"
ruby_version="1.9.3"

function install_ruby_if_needed() {
  echo "Checking for Ruby $ruby_version..."
  if ! rvm list strings | grep "ruby-$ruby_version" > /dev/null; then
    rvm install "ruby-$ruby_version" || exit 1
  fi
}

function install_bundler_if_needed() {
  echo "Checking for Bundler..."
  gem install bundler --conservative || exit 1
}

function update_gems_if_needed() {
  echo "Installing gems..."
  bundle check || bundle install || exit 1
}

function reset_database() {
  echo "Resetting database..."
  RAILS_ENV=test bundle exec rake db:drop db:create db:schema:load || exit 1
}

function run_tests() {
  echo "Running tests..."
  bundle exec rake spec
}

install_ruby_if_needed
source .rvmrc
install_bundler_if_needed
update_gems_if_needed
reset_database
run_tests
