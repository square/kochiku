class ApplicationController < ActionController::Base
  include BuildHelper

  rescue_from ActiveRecord::RecordNotFound do |exception|
    render "#{Rails.public_path}/404.html", :layout => false, :status => 404
  end
end
