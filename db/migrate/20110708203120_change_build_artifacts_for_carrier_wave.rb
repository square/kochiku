class ChangeBuildArtifactsForCarrierWave < ActiveRecord::Migration
  def self.up
    rename_column :build_artifacts, :name, :log_file
    remove_column :build_artifacts, :content
  end

  def self.down
    add_column    :build_artifacts, :content, :text
    rename_column :build_artifacts, :log_file, :name
  end
end
