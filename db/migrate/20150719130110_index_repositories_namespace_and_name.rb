class IndexRepositoriesNamespaceAndName < ActiveRecord::Migration
  def change
    add_index :repositories, [:namespace, :name], unique: true
  end
end
