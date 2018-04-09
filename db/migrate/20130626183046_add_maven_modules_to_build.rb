class AddMavenModulesToBuild < ActiveRecord::Migration[5.0]
  def change
    add_column :builds, :maven_modules, :text
  end
end
