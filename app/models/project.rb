class Project < ActiveRecord::Base
  has_many :builds, :dependent => :destroy
  validates_uniqueness_of :name

  def to_param
    self.name.downcase
  end
end
