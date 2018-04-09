class AddOptionsToBuildPart < ActiveRecord::Migration[5.1]
  def change
    add_column :build_parts, :options, :text
  end
end
