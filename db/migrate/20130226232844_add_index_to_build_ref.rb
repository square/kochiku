class AddIndexToBuildRef < ActiveRecord::Migration[5.1]
  def change
    add_index :builds, :ref
  end
end
