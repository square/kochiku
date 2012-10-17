class AddTargetNameToBuilds < ActiveRecord::Migration
  def change
    add_column :builds, :target_name, :string
  end
end
