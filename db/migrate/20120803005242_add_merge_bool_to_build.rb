class AddMergeBoolToBuild < ActiveRecord::Migration[5.1]
  def change
    add_column :builds, :auto_merge, :boolean
  end
end
