puts %w(BuildPartId BuildAttemptId Builder TestType State Duration CreatedAt).join(',')
BuildAttempt.order(:build_part_id).includes(:build_part).find_each do |ba|
  next if ba.started_at.nil? || ba.finished_at.nil?
  puts [ba.build_part_id, ba.id, ba.builder, ba.build_part.kind, ba.state, sprintf("%.1f", (ba.finished_at - ba.started_at)/60.0), ba.created_at].join(',')
end
