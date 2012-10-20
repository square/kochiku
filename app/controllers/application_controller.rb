class ApplicationController < ActionController::Base
  include BuildHelper
  protect_from_forgery
end
