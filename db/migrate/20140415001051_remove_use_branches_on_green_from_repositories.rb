class RemoveUseBranchesOnGreenFromRepositories < ActiveRecord::Migration[5.0]
  def change
    remove_column :repositories, :use_branches_on_green, :boolean
  end
end
