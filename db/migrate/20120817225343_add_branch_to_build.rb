class AddBranchToBuild < ActiveRecord::Migration[5.1]
  def change
    add_column :builds, :branch, :string
  end
end
