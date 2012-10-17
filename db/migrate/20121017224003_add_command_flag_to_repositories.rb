class AddCommandFlagToRepositories < ActiveRecord::Migration
  def change
    add_column :repositories, :command_flag, :string
  end
end
