class CreateProjects < ActiveRecord::Migration
  def self.up
    create_table :projects do |t|
      t.string :name
      t.string :branch

      t.timestamps
    end
    add_index :projects, [:name, :branch]
  end

  def self.down
    drop_table :projects
  end
end
