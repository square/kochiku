class DashboardsController < ApplicationController

  def build_history_by_worker
    build_attempts = BuildAttempt.order('id DESC').limit(params[:count] || 2000).select(:id, :builder, :state)

    @workers = build_attempts.group_by { |ba| ba.builder }
  end

end
