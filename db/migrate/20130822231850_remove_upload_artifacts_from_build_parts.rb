class RemoveUploadArtifactsFromBuildParts < ActiveRecord::Migration[5.0]
  def up
    remove_column :build_parts, :upload_artifacts
  end

  def down
    add_column :build_parts, :upload_artifacts, :boolean
  end
end
