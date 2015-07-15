class AddLogPortToBuildAttempt < ActiveRecord::Migration
  def change
    add_column :build_attempts, :log_streamer_port, :integer
  end
end
