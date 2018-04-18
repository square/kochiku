class AddCommandFlagToRepositories < ActiveRecord::Migration[5.0]
  def change
    add_column :repositories, :command_flag, :string
  end
end
