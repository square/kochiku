class IndexRepositoriesNamespaceAndName < ActiveRecord::Migration[5.0]
  def change
    add_index :repositories, [:namespace, :name], unique: true
  end
end
