class CreateBuildArtifacts < ActiveRecord::Migration
  def self.up
    create_table :build_artifacts do |t|
      t.integer :build_part_result_id
      t.string :type
      t.text :content

      t.timestamps
    end
  end

  def self.down
    drop_table :build_artifacts
  end
end
