class AddUploadArtifactsToBuildParts < ActiveRecord::Migration[5.1]
  def change
    add_column :build_parts, :upload_artifacts, :boolean
  end
end
