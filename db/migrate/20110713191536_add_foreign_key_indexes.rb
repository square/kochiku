class AddForeignKeyIndexes < ActiveRecord::Migration
  def self.up
    add_index :build_parts, :build_id
    add_index :build_attempts, :build_part_id
    add_index :build_artifacts, :build_attempt_id
  end

  def self.down
    remove_index :build_parts, :build_id
    remove_index :build_attempts, :build_part_id
    remove_index :build_artifacts, :build_attempt_id
  end
end
