class Project < ActiveRecord::Base
  has_many :builds
  validates_uniqueness_of :branch, :scope => :name

  def name_with_branch
    "#{self.name}-#{self.branch}"
  end
  
  def to_param
    self.name.downcase
  end
end
