class AddRetryCountToBuildPart < ActiveRecord::Migration[5.0]
  def change
    add_column :build_parts, :retry_count, :integer, default: 0
  end
end
