class AddDeployableMapToBuild < ActiveRecord::Migration
  def change
    add_column :builds, :deployable_map, :text
  end
end
