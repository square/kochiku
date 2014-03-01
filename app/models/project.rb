class Project < ActiveRecord::Base
  has_many :builds, :dependent => :destroy, :inverse_of => :project do
    def create_new_build_for(sha)
      last_build = last
      return last_build if last_build && !last_build.completed?
      build = where(ref: sha).first_or_initialize(state: :partitioning, branch: 'master')
      build.save!
      build
    end

    def find_existing_build_or_initialize(ref, initialization_values)
      existing_build = Build.joins(:project).where("projects.repository_id = ? AND builds.ref = ?", proxy_association.owner.repository_id, ref).readonly(false).first
      existing_build || build(initialization_values.merge(:ref => ref))
    end

    def for_branch(branch)
      joins(:project).where(
        "projects.repository_id" => proxy_association.owner.repository_id,
        "builds.branch" => branch,
        "builds.state" => Build::IN_PROGRESS_STATES)
    end
  end
  belongs_to :repository

  validates_uniqueness_of :name

  def ensure_master_build_exists(sha)
    builds.create_new_build_for(sha)
  end

  def ensure_branch_build_exists(branch, sha)
    build = builds.find_existing_build_or_initialize(sha, :state  => :partitioning, :branch => branch)
    abort_in_progress_builds_for_branch(branch, build)
    build.save!
    build
  end

  def abort_in_progress_builds_for_branch(branch, current_build)
    builds.for_branch(branch).readonly(false).each { |build| build.abort! unless build == current_build }
  end

  def to_param
    self.name.downcase
  end

  def main?
    self.name == repository.repository_name
  end
end
