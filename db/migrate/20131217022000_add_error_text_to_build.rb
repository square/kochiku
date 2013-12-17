class AddErrorTextToBuild < ActiveRecord::Migration
  def change
    add_column :builds, :error_details, :text
  end
end
