class BuildPart < ActiveRecord::Base
  has_many :build_part_results
  belongs_to :build

  serialize :paths, Array
end
