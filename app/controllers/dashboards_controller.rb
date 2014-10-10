class DashboardsController < ApplicationController

  def build_history_by_worker
    build_attempts = BuildAttempt.where("builder IS NOT NULL").order('id DESC').limit(params[:count] || 2000).select(:id, :builder, :state)

    @workers = build_attempts.group_by { |ba| ba.builder }

    @partition_jobs = Build.order('id DESC').limit(150).select(:id, :state).includes(:build_parts)
  end

end
