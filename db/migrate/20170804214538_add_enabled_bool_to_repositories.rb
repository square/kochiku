class AddEnabledBoolToRepositories < ActiveRecord::Migration[5.1]
  def change
    add_column :repositories, :enabled, :boolean, default: true, null: false
  end
end
