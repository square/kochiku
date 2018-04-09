class RemoveOptionsFromRepository < ActiveRecord::Migration[5.1]
  def change
    remove_column :repositories, :options
  end
end
