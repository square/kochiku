class AddAllowsKochikuMergesToRepository < ActiveRecord::Migration
  def change
    add_column :repositories, :allows_kochiku_merges, :boolean, default: true
  end
end
