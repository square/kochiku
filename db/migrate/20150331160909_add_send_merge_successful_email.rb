class AddSendMergeSuccessfulEmail < ActiveRecord::Migration
  def change
    add_column :repositories, :send_merge_successful_email, :boolean, default: true, null: false
  end
end
