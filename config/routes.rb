require 'resque/server'

Kochiku::Application.routes.draw do
  mount Resque::Server.new, :at => '/resque'

  root :to => "projects#ci_projects"

  resources :repositories do
    member do
      get :projects
    end
  end

  resources :projects, :only => [:index, :new, :show] do
    get 'status-report', :action => "status_report", :on => :collection
    get 'build-time-history', :action => "build_time_history", :defaults => { :format => 'json' }
    #get ':path', :action => "build_feed", :on => member, :defaults => { :format => 'xml' }

    resources :builds, :only => [:index, :create, :show] do
      post 'request', :action => "request_build", :on => :collection
      post 'toggle-auto-merge', :action => "toggle_auto_merge", :on => :member, :as => :toggle_auto_merge
      put 'abort', :action => "abort", :on => :member
      get 'status', :action => "build_status", :on => :member, :defaults => { :format => 'json' }
      post 'rebuild-failed-parts', :action => "rebuild_failed_parts", :on => :member, :as => :rebuild_failed_parts
      resources :build_parts, :as => 'parts', :path => 'parts', :only => [:show] do
        post 'rebuild', :on => :member
      end
    end
  end
  match '/XmlStatusReport.aspx', :to => "projects#status_report", :defaults => { :format => 'xml' }

  #match '/projects/:project_id/:path' => "projects#path_feed", :via => :get, :defaults => { :format => 'xml' }
  match '/tmp/api/json' => "builds#index"
  match '/tmp/job/Amex-Certification/api/json' => "builds#module_info"
  match '/tmp/job/Amex-Certification/lastCompletedBuild/api/json' => "builds#last_build_info"
  match '/build_attempts/:build_attempt_id/build_artifacts' => "build_artifacts#create", :via => :post
  match '/build_attempts/:id/start' => "build_attempts#start", :via => :post
  match '/build_attempts/:id/finish' => "build_attempts#finish", :via => :post, :as => :finish_build_attempt
  match '/pull-request-builder' => "pull_requests#build", :via => :post, :as => :pull_request_build
end
# TODO routing specs
