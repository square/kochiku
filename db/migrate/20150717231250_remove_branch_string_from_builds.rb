class RemoveBranchStringFromBuilds < ActiveRecord::Migration[5.1]
  def change
    # The previous migration (AssignBuildsToBranches) mapped branch_id on
    # builds to the newly introduced Branch records. With that complete it is
    # safe to remove the legacy branch (string) column from builds.
    remove_column :builds, :branch, :string
  end
end
