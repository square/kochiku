class AddLogPortToBuildAttempt < ActiveRecord::Migration[5.1]
  def change
    add_column :build_attempts, :log_streamer_port, :integer
  end
end
