class AddRetryCountToBuildPart < ActiveRecord::Migration[5.1]
  def change
    add_column :build_parts, :retry_count, :integer, default: 0
  end
end
