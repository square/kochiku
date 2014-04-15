class RemoveCommandFlagFromRepositories < ActiveRecord::Migration
  def change
    remove_column :repositories, :command_flag, :string
    remove_column :builds,       :target_name,  :string
  end
end
