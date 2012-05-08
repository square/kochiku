# Require the files in lib that need to be loaded here
require 'git_repo'
require "#{Rails.root}/lib/build_strategies/#{Rails.env}_build_strategy"
