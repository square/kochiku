require 'build'
require 'build_attempt'

class RenameErrorStateToErrored < ActiveRecord::Migration
  def self.up
    BuildAttempt.update_all({:state => 'errored'}, {:state => 'error'})
    Build.update_all({:state => 'errored'}, {:state => 'error'})
  end

  def self.down
    BuildAttempt.update_all({:state => 'error'}, {:state => 'errored'})
    Build.update_all({:state => 'error'}, {:state => 'errored'})
  end
end
