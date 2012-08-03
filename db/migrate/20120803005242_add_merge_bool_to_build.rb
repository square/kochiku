class AddMergeBoolToBuild < ActiveRecord::Migration
  def change
    add_column :builds, :auto_merge, :boolean
  end
end
