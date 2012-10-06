class AddPullRequestToBuild < ActiveRecord::Migration
  def change
    add_column :builds, :pull_request, :string
  end
end
