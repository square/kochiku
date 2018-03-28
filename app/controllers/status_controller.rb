class StatusController < ApplicationController

  def available
    if File.exist?(Rails.root.join("tmp/maintenance"))
      head :service_unavailable
    else
      head :ok
    end
  end

end
