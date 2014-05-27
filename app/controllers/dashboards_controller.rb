class DashboardsController < ApplicationController

  def build_history_by_worker
    build_attempts = BuildAttempt.order('id DESC').limit(params[:count] || 2000).select(:builder, :state)

    @workers = {}
    build_attempts.each do |attempt|
      if @workers.has_key? attempt.builder
        @workers[attempt.builder] << attempt.state
      else
        @workers[attempt.builder] = [attempt.state]
      end
    end
  end

end
