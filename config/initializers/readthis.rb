if Rails.env.staging? || Rails.env.production?
  # Allow Rails to continue serving requests if Redis crashes
  # https://github.com/sorentwo/readthis#fault-tolerance
  Readthis.fault_tolerant = true
end
