class AddOnSuccessLogFileToBuild < ActiveRecord::Migration
  def change
    add_column :builds, :on_success_script_log_file, :string
  end
end
