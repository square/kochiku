class IndexRepositoriesNamespaceAndName < ActiveRecord::Migration[5.1]
  def change
    add_index :repositories, [:namespace, :name], unique: true
  end
end
