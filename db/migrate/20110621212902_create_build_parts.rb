class CreateBuildParts < ActiveRecord::Migration
  def self.up
    create_table :build_parts do |t|
      t.integer :build_id
      t.string :type
      t.text :paths

      t.timestamps
    end
  end

  def self.down
    drop_table :build_parts
  end
end
