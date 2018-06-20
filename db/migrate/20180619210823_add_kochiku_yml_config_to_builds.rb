class AddKochikuYmlConfigToBuilds < ActiveRecord::Migration[5.1]
  def change
    add_column :builds, :kochiku_yml_config, :text
  end
end
