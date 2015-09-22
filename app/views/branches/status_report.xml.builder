xml.Projects do
  @branches.each do |branch|
    # currently cimonitor only utilizes the activity attribute
    xml.Project({
      :name => branch.repository.to_param + (branch.name == 'master' ? '' : ('/' + branch.name)),
      :activity => build_activity(branch.builds.last),
      :lastBuildLabel => branch.builds.last.object_id,
      :webUrl => repository_branch_url(branch.repository, branch),
      :lastBuildStatus => (branch.last_completed_build.try(:succeeded?) ? "Success" : "Failure"),
      :lastBuildTime => branch.last_completed_build.try(:finished_at).try(:strftime, "%Y-%m-%dT%H:%M:%SZ")
    })
  end
end
