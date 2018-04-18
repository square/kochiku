class RemoveOptionsFromRepository < ActiveRecord::Migration[5.0]
  def change
    remove_column :repositories, :options
  end
end
