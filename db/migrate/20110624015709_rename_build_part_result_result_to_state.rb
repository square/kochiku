class RenameBuildPartResultResultToState < ActiveRecord::Migration
  def self.up
    rename_column :build_part_results, :result, :state
  end

  def self.down
    rename_column :build_part_results, :state, :result
  end
end
