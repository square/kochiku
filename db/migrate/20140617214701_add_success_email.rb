class AddSuccessEmail < ActiveRecord::Migration[5.1]
  def change
    add_column :builds, :build_success_email_sent, :boolean, :default => false, :null => false
    add_column :repositories, :send_build_success_email, :boolean, :default => true, :null => false
    reversible do |dir|
      change_table :builds do |t|
        dir.up do
          execute 'UPDATE builds SET build_failure_email_sent = 0 WHERE build_failure_email_sent IS NULL'
          t.change :build_failure_email_sent, :boolean, :default => false, :null => false
        end
        dir.down { t.change :build_failure_email_sent, :boolean, :default => nil, :null => true }
      end
      change_table :repositories do |t|
        dir.up do
          execute 'UPDATE repositories SET send_build_failure_email = 1 WHERE send_build_failure_email IS NULL'
          t.change :send_build_failure_email, :boolean, :default => true, :null => false
        end
        dir.down { t.change :send_build_failure_email, :boolean, :default => true, :null => true }
      end
    end
  end
end
