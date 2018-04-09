class CreateProjects < ActiveRecord::Migration[5.1]
  def self.up
    create_table :projects do |t|
      t.string :name
      t.string :branch

      t.timestamps(null: false)
    end
    add_index :projects, [:name, :branch]
  end

  def self.down
    drop_table :projects
  end
end
