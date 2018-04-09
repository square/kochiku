class RenameErrorStateToErrored < ActiveRecord::Migration[5.1]
  def self.up
    execute("UPDATE build_attempts SET state='errored' WHERE state='error'")
    execute("UPDATE builds SET state='errored' WHERE state='error'")
  end

  def self.down
    execute("UPDATE builds SET state='error' WHERE state='errored'")
    execute("UPDATE build_attempts SET state='error' WHERE state='errored'")
  end
end
