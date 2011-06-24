class ChangeArtifactTypeToName < ActiveRecord::Migration
  def self.up
    rename_column :build_artifacts, :type, :name
  end

  def self.down
    rename_column :build_artifacts, :name, :type
  end
end
