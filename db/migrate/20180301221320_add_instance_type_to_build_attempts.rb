class AddInstanceTypeToBuildAttempts < ActiveRecord::Migration
  def change
    add_column :build_attempts, :instance_type, :string
  end
end
