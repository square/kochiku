class RemoveJavaSpecificStuff < ActiveRecord::Migration
  def up
   remove_column :builds, :deployable_map
   remove_column :builds, :maven_modules
  end

  def down
    add_column :builds, :deployable_map, :text
    add_column :builds, :maven_modules, :text
  end
end
