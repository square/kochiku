class AddInstanceTypeToBuildAttempts < ActiveRecord::Migration[5.1]
  def change
    add_column :build_attempts, :instance_type, :string
  end
end
