class FixRepositorySchema < ActiveRecord::Migration[5.0]
  def change
    add_column :repositories, :run_ci, :boolean
    add_column :repositories, :use_branches_on_green, :boolean
    add_column :repositories, :build_pull_requests, :boolean
    add_column :repositories, :on_green_update, :string
    add_column :repositories, :use_spec_and_ci_queues, :boolean
    add_column :repositories, :repo_cache_dir, :string
  end
end
