class RenameBuildsShaToRef < ActiveRecord::Migration[5.0]
  def self.up
    rename_column :builds, :sha, :ref
  end

  def self.down
    rename_column :builds, :ref, :sha
  end
end
