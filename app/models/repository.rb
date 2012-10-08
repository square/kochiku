class Repository < ActiveRecord::Base
  has_many :projects
  serialize :options, Hash
  validates_presence_of :url

end
