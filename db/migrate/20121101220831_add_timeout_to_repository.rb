class AddTimeoutToRepository < ActiveRecord::Migration[5.1]
  def change
    add_column :repositories, :timeout, :integer, :default => 40
  end
end
