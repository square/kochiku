class RemoveNotes < ActiveRecord::Migration
  def change
    remove_column :repositories, :on_success_note, :string
  end
end
