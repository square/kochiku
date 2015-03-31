class RemoveOnSuccessScriptFromRepositories < ActiveRecord::Migration
  def up
    # Guard against deleting any data
    rows_with_old_data = select_value("select count(*) from repositories where on_success_script IS NOT NULL AND on_success_script != ''")

    if rows_with_old_data > 0
      puts
      puts "Found #{rows_with_old_data} rows in the Repositories table with non-empty values"
      puts "for `on_success_script`."
      puts
      puts "Kochiku no longer supports on_success_script inside of the repository table."
      puts "The new location is inside of each project's kochiku.yml file."
      puts
      puts "Please remove the data from the on_success_script column and re-run this migration."
      exit(1)
    end

    remove_column :repositories, :on_success_script, :string
  end

  def down
    add_column :repositories, :on_success_script, :string
  end
end
