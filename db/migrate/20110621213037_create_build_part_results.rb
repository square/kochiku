class CreateBuildPartResults < ActiveRecord::Migration
  def self.up
    create_table :build_part_results do |t|
      t.integer :build_part_id
      t.datetime :started_at
      t.datetime :finished_at
      t.string :result

      t.timestamps
    end
  end

  def self.down
    drop_table :build_part_results
  end
end
