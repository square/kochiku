class KochikuQuantityReport < ActiveRecord::Base
  validates :target_ts, uniqueness: { scope: [:frequency] }
end
