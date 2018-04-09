class RenameAutoMergeOnBuild < ActiveRecord::Migration[5.0]
  def change
    rename_column :builds, :auto_merge, :merge_on_success
  end
end
