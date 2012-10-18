class AddOptionsToBuildPart < ActiveRecord::Migration
  def change
    add_column :build_parts, :options, :text
  end
end
