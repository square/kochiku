class AddProjectIdToBuilds < ActiveRecord::Migration
  def self.up
    add_column :builds, :project_id, :integer
    add_index  :builds, :project_id
  end

  def self.down
    remove_index  :builds, column: :project_id
    remove_column :builds, :project_id
  end
end
