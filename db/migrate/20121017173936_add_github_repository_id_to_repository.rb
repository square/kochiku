class AddGithubRepositoryIdToRepository < ActiveRecord::Migration
  def change
    add_column :repositories, :github_post_receive_hook_id, :integer
  end
end
