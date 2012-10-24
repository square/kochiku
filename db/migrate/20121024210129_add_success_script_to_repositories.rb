class AddSuccessScriptToRepositories < ActiveRecord::Migration
  def change
    add_column :repositories, :on_success_script, :string
    add_column :builds, :promoted, :boolean
  end
end
