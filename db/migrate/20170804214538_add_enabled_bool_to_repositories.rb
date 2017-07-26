class AddEnabledBoolToRepositories < ActiveRecord::Migration
  def change
    add_column :repositories, :enabled, :boolean, default: true, null: false
  end
end
