class ApplicationController < ActionController::Base
  include Squash::Ruby::ControllerMethods
  enable_squash_client

  include BuildHelper
  protect_from_forgery
end
