class AddOptionsToBuildPart < ActiveRecord::Migration[5.0]
  def change
    add_column :build_parts, :options, :text
  end
end
