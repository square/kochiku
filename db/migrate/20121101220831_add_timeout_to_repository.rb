class AddTimeoutToRepository < ActiveRecord::Migration
  def change
    add_column :repositories, :timeout, :integer, :default => 40
  end
end
