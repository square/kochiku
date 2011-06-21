class CreateBuilds < ActiveRecord::Migration
  def self.up
    create_table :builds do |t|
      t.string :sha
      t.string :state
      t.string :queue

      t.timestamps
    end
  end

  def self.down
    drop_table :builds
  end
end
