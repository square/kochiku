class StatusController < ApplicationController

  def available
    if File.exist?(Rails.root.join("tmp/maintenance"))
      render :nothing => true, :status => :service_unavailable
    else
      render :nothing => true, :status => :ok
    end
  end

end
