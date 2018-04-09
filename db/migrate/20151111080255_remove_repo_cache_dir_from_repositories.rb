class RemoveRepoCacheDirFromRepositories < ActiveRecord::Migration[5.1]
  def change
    remove_column :repositories, :repo_cache_dir, :string
  end
end
