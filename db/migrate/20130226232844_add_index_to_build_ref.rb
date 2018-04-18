class AddIndexToBuildRef < ActiveRecord::Migration[5.0]
  def change
    add_index :builds, :ref
  end
end
