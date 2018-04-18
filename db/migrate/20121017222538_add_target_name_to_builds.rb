class AddTargetNameToBuilds < ActiveRecord::Migration[5.0]
  def change
    add_column :builds, :target_name, :string
  end
end
