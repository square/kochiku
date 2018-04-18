class AddDeployableMapToBuild < ActiveRecord::Migration[5.0]
  def change
    add_column :builds, :deployable_map, :text
  end
end
