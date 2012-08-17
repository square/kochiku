class AddBranchToBuild < ActiveRecord::Migration
  def change
    add_column :builds, :branch, :string
  end
end