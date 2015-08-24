# In this migration intentionally go out of our way to not use the Project
# model so that it can be removed from the codebase.
class AssignBuildsToBranches < ActiveRecord::Migration
  def up
    # Be mindful of build.branch versus build#branch_id
    # `build.branch` is a reference to the name of the branch as a string
    Build.find_each do |build|
      branch_record = nil
      repository_id = connection.select_value("SELECT repository_id FROM projects WHERE id = #{build.project_id}")

      if build.branch.present?
        branch_record = Branch.find_or_create_by(repository_id: repository_id, name: build.branch)
      else
        branch_record = Branch.find_or_create_by(repository_id: repository_id, name: "unknown")
      end

      build.update_attribute(:branch_id, branch_record.id)
    end

    # Automatically set all master branches as convergence branches to maintain
    # previous behavior.
    Branch.where(name: 'master').update_all(convergence: true)

    # Now that a relationship has been established between the Build and a
    # Branch record, the string branch column can be removed from Build.
    remove_column :builds, :branch, :string
  end

  # Warning: this will add the column back but it will not recover the data.
  def down
    add_column :builds, :branch, :string
  end
end
