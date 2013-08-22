class RemoveUploadArtifactsFromBuildParts < ActiveRecord::Migration
  def up
    remove_column :build_parts, :upload_artifacts
  end

  def down
    add_column :build_parts, :upload_artifacts, :boolean
  end
end
