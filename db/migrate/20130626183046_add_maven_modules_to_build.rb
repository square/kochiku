class AddMavenModulesToBuild < ActiveRecord::Migration
  def change
    add_column :builds, :maven_modules, :text
  end
end
