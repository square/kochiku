class AddTestCommandToBuilds < ActiveRecord::Migration
  def change
    add_column :builds, :test_command, :string
  end
end
