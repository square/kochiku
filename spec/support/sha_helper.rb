def to_40(short)
  multiplier = (40.0 / short.length).ceil
  (short * multiplier).slice(0, 40)
end
