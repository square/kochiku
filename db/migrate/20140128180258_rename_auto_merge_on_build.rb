class RenameAutoMergeOnBuild < ActiveRecord::Migration
  def change
    rename_column :builds, :auto_merge, :merge_on_success
  end
end
