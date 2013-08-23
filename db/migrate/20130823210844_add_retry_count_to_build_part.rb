class AddRetryCountToBuildPart < ActiveRecord::Migration
  def change
    add_column :build_parts, :retry_count, :integer, default: 0
  end
end
