class AddsAutomergeDisabledToRepsoitory < ActiveRecord::Migration
  def up
    add_column :repositories, :automerge_disabled, :boolean
  end

  def down
    remove_column :repositories, :automerge_disabled
  end
end
