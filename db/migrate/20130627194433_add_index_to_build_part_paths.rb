class AddIndexToBuildPartPaths < ActiveRecord::Migration
  def change
    add_index :build_parts, :paths, :length => {:paths => 255}
  end
end
