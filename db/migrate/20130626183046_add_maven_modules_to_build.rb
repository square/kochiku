class AddMavenModulesToBuild < ActiveRecord::Migration[5.1]
  def change
    add_column :builds, :maven_modules, :text
  end
end
