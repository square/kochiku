class AddOnSuccessNoteToRepositories < ActiveRecord::Migration[5.0]
  def change
    add_column :repositories, :on_success_note, :string
  end
end
