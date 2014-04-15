class RemoveUseBranchesOnGreenFromRepositories < ActiveRecord::Migration
  def change
    remove_column :repositories, :use_branches_on_green, :boolean
  end
end
