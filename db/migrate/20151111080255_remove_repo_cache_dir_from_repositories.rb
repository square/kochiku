class RemoveRepoCacheDirFromRepositories < ActiveRecord::Migration
  def change
    remove_column :repositories, :repo_cache_dir, :string
  end
end
