class AddIndexToBuildRef < ActiveRecord::Migration
  def change
    add_index :builds, :ref
  end
end
