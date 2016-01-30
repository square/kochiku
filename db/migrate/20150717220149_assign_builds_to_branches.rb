# In this migration intentionally go out of our way to not use the Project
# model so that it can be removed from the codebase.
class AssignBuildsToBranches < ActiveRecord::Migration
  def up
    # Be mindful of build.branch versus build#branch_id
    # `build.branch` is a reference to the name of the branch as a string
    Build.where(branch_id: nil).find_each do |build|
      repository_id = connection.select_value("SELECT repository_id FROM projects WHERE id = #{build.project_id}")

      if repository_id.nil?
        puts "skipping Build #{build.id} because its project or repository not longer exists"
        next
      end

      branch_record = if build.branch.present?
                        Branch.find_or_create_by(repository_id: repository_id, name: build.branch)
                      else
                        Branch.find_or_create_by(repository_id: repository_id, name: "unknown")
                      end

      build.update_column(:branch_id, branch_record.id)
    end

    # Automatically set all master branches as convergence branches to maintain
    # previous behavior.
    Branch.where(name: 'master').update_all(convergence: true)

    # the 'branch' column is removed from builds in the next migration
  end

  def down
  end
end
