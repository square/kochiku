class CreateRepositories < ActiveRecord::Migration[5.1]
  def change
    create_table :repositories do |t|
      t.string :url
      t.string :test_command
      t.text :options
      t.timestamps(null: false)
    end
    add_index :repositories, :url
    add_column :projects, :repository_id, :integer
    add_index :projects, :repository_id
  end
end
