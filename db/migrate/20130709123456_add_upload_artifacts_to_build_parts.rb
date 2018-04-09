class AddUploadArtifactsToBuildParts < ActiveRecord::Migration[5.0]
  def change
    add_column :build_parts, :upload_artifacts, :boolean
  end
end
