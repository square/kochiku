Kochiku::Application.routes.draw do
  require "resque_web"
  ResqueWeb::Engine.eager_load!  # workaround for https://github.com/resque/resque-web/issues/29
  mount ResqueWeb::Engine => "/resque"

  root :to => "projects#ci_projects"

  # /repositories/1/build-ref?ref=master&sha=abc123
  resources :repositories do
    member do
      get :projects
      post "build-ref", :action => 'build_ref', :as => 'build_ref'
    end
  end

  resources :projects, :only => [:index, :new, :show] do
    get 'status-report', :action => "status_report", :on => :collection
    get 'build-time-history', :action => "build_time_history", :defaults => { :format => 'json' }
    get 'health', :action => 'health', :on => :member

    resources :builds, :only => [:create, :show] do
      post 'request', :action => "request_build", :on => :collection
      post 'toggle-merge-on-success', :action => "toggle_merge_on_success", :on => :member, :as => :toggle_merge_on_success
      patch 'abort', :action => "abort", :on => :member
      get 'status', :action => "build_status", :on => :member, :defaults => { :format => 'json' }
      post 'rebuild-failed-parts', :action => "rebuild_failed_parts", :on => :member, :as => :rebuild_failed_parts
      post 'retry-partitioning', :action => "retry_partitioning", :on => :member, :as => :retry_partitioning
      get 'modified_time', :action => "modified_time", :on => :member, :defaults => { :format => 'json' }
      resources :build_parts, :as => 'parts', :path => 'parts', :only => [:show] do
        post 'rebuild', :on => :member
        get 'modified_time', :action => "modified_time", :on => :member, :defaults => { :format => 'json' }
      end
    end
  end

  match '/XmlStatusReport.aspx', to: "projects#status_report", defaults: {:format => 'xml'}, via: :get
  match '/worker_health', to: "dashboards#build_history_by_worker", via: :get, as: :build_history_by_worker

  match 'builds/:id' => "builds#build_redirect", :via => :get, :as => :build_redirect, :id => /\d+/
  match 'builds/:ref' => "builds#build_ref_redirect", :via => :get, :as => :build_ref_redirect
  match '/build_attempts/:build_attempt_id/build_artifacts' => "build_artifacts#create", :via => :post
  match '/build_attempts/:id/start' => "build_attempts#start", :via => :post
  match '/build_attempts/:id/finish' => "build_attempts#finish", :via => :post, :as => :finish_build_attempt
  match '/build_attempts/:id/build_part' => "build_attempts#build_part", :via => :get, :as => :build_part_redirect
  match '/build_attempts/:id/stream_logs' => "build_attempts#stream_logs", :via => :get, :as => :stream_logs
  match '/build_attempts/:id/stream_logs_chunk' => "build_attempts#stream_logs_chunk", :via => :get, :as => :stream_logs_chunk
  match '/pull-request-builder' => "pull_requests#build", :via => :post, :as => :pull_request_build

  resources :build_artifacts, :only => [:show]
end
# TODO routing specs
