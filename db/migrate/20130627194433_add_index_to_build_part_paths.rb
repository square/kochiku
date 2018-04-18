class AddIndexToBuildPartPaths < ActiveRecord::Migration[5.0]
  def change
    add_index :build_parts, :paths, :length => {:paths => 255}
  end
end
