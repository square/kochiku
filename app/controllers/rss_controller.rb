require 'json'

class RssController < ApplicationController
  before_filter :load_project, :only => [:show, :abort, :build_status, :toggle_auto_merge, :rebuild_failed_parts, :request_build]
  skip_before_filter :verify_authenticity_token, :only => [:create]

  def index
    @test = JSON.parse(File.read('./tmp/index.json'))
    render :json => @test
  end

  def module_info
    @test = JSON.parse(File.read('./tmp/module.json'))
    render :json => @test
  end

  def last_build_info
    @test = JSON.parse(File.read('./tmp/last-completed.json'))
    render :json => @test
  end
end