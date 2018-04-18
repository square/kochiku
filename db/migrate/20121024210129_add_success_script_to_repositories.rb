class AddSuccessScriptToRepositories < ActiveRecord::Migration[5.0]
  def change
    add_column :repositories, :on_success_script, :string
    add_column :builds, :promoted, :boolean
  end
end
