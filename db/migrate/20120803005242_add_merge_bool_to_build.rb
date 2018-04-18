class AddMergeBoolToBuild < ActiveRecord::Migration[5.0]
  def change
    add_column :builds, :auto_merge, :boolean
  end
end
