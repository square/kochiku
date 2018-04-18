class RemoveRepoCacheDirFromRepositories < ActiveRecord::Migration[5.0]
  def change
    remove_column :repositories, :repo_cache_dir, :string
  end
end
