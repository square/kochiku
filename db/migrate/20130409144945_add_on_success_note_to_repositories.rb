class AddOnSuccessNoteToRepositories < ActiveRecord::Migration
  def change
    add_column :repositories, :on_success_note, :string
  end
end
