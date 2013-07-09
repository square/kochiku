class AddUploadArtifactsToBuildParts < ActiveRecord::Migration
  def change
    add_column :build_parts, :upload_artifacts, :boolean
  end
end
