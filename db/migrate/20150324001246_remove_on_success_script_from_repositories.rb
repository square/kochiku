class RemoveOnSuccessScriptFromRepositories < ActiveRecord::Migration[5.1]
  def up
    # Guard against deleting any data
    rows_with_old_data = select_value("select count(*) from repositories where on_success_script IS NOT NULL AND on_success_script != ''")

    if rows_with_old_data > 0
      err_message = <<-ERR_MESSAGE
        "Found #{rows_with_old_data} rows in the Repositories table with non-empty values"
        "for `on_success_script`."

        "Kochiku no longer supports on_success_script inside of the repository table."
        "The new location is inside of each project's kochiku.yml file."

        "Please remove the data from the on_success_script column and re-run this migration."
      ERR_MESSAGE

      Rails.logger.error(err_message)
      exit(1)
    end

    remove_column :repositories, :on_success_script, :string
  end

  def down
    add_column :repositories, :on_success_script, :string
  end
end
