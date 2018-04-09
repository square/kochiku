class IndexCreatedAtOnBuildAttempts < ActiveRecord::Migration[5.0]
  def change
    add_index :build_attempts, :created_at
  end
end
