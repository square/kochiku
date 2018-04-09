class AddErrorTextToBuild < ActiveRecord::Migration[5.1]
  def change
    add_column :builds, :error_details, :text
  end
end
