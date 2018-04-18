class RemoveNotes < ActiveRecord::Migration[5.0]
  def change
    remove_column :repositories, :on_success_note, :string
  end
end
