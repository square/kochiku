class RemoveOptionsFromRepository < ActiveRecord::Migration
  def change
    remove_column :repositories, :options
  end
end
