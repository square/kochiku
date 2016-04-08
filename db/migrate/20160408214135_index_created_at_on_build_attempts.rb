class IndexCreatedAtOnBuildAttempts < ActiveRecord::Migration
  def change
    add_index :build_attempts, :created_at
  end
end
