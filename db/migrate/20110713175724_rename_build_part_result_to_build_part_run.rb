class RenameBuildPartResultToBuildPartRun < ActiveRecord::Migration[5.0]
  def self.up
    rename_table :build_part_results, :build_attempts
    rename_column :build_artifacts, :build_part_result_id, :build_attempt_id
  end

  def self.down
    rename_column :build_artifacts, :build_attempt_id, :build_part_result_id
    rename_table :build_attempts, :build_part_results
  end
end
