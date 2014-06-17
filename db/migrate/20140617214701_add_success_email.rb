class AddSuccessEmail < ActiveRecord::Migration
  def change
    add_column :builds, :build_success_email_sent, :boolean, :default => false, :null => false
    add_column :repositories, :send_build_success_email, :boolean, :default => true, :null => false
    reversible do |dir|
      change_table :builds do |t|
        dir.up { t.change :build_failure_email_sent, :boolean, :default => false, :null => false }
        dir.down { t.change :build_failure_email_sent, :boolean, :default => nil, :null => true }
      end
      change_table :repositories do |t|
        dir.up { t.change :send_build_failure_email, :boolean, :default => true, :null => false }
        dir.down { t.change :send_build_failure_email, :boolean, :default => true, :null => true }
      end
    end
  end
end
