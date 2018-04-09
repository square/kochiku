class IndexCreatedAtOnBuildAttempts < ActiveRecord::Migration[5.1]
  def change
    add_index :build_attempts, :created_at
  end
end
