require 'resque/server'

Kochiku::Application.routes.draw do
  mount Resque::Server.new, :at => '/resque'

  if Rails.env.development?
    # https://github.com/rails/rails/pull/17896
    get '/rails/mailers' => "rails/mailers#index"
    get '/rails/mailers/*path' => "rails/mailers#preview"
  end

  root :to => "repositories#dashboard"

  get '/_status' => "status#available"

  # /repositories/1/build-ref?ref=master&sha=abc123
  resources :repositories, only: [:index, :create, :new, :update, :destroy] do
    member do
      post "build-ref", :action => 'build_ref', :as => 'build_ref'
    end
  end

  match '/XmlStatusReport.aspx', to: "branches#status_report", defaults: {:format => 'xml'}, via: :get
  match '/worker_health', to: "dashboards#build_history_by_worker", via: :get, as: :build_history_by_worker

  match 'builds/:id' => "builds#build_redirect", :via => :get, :as => :build_redirect, :id => /\d+/
  match 'builds/:id/status' => "builds#build_status", :via => :get, :as => :build_status, :id => /\d+/, :defaults => { :format => 'json' }
  match 'builds/:ref' => "builds#build_ref_redirect", :via => :get, :as => :build_ref_redirect
  match '/build_attempts/:build_attempt_id/build_artifacts' => "build_artifacts#create", :via => :post
  match '/build_attempts/:id/start' => "build_attempts#start", :via => :post
  match '/build_attempts/:id/finish' => "build_attempts#finish", :via => :post, :as => :finish_build_attempt
  # left here for backward compatibility in case if anyone uses it. /build_attempts/:id should be used instead.
  match '/build_attempts/:id/build_part' => "build_attempts#show", :via => :get, :as => :build_part_redirect
  match '/build_attempts/:id/stream_logs' => "build_attempts#stream_logs", :via => :get, :as => :stream_logs
  match '/build_attempts/:id/stream_logs_chunk' => "build_attempts#stream_logs_chunk", :via => :get, :as => :stream_logs_chunk
  match '/pull-request-builder' => "pull_requests#build", :via => :post, :as => :pull_request_build
  get 'badge/*repository_path', to: 'branches#badge'

  # Redirects for legacy urls
  get '/projects/:project_id/builds/:build_id', to: redirect('/builds/%{build_id}')

  resources :build_artifacts, :only => [:show]
  resources :builds, only: [:create]
  resources :build_attempts, only: [:show]

  scope path: "*repository_path", as: 'repository', constraints: { repository_path: /[^\/]+\/[^\/]+/ }, format: false do
    get 'edit', to: 'repositories#edit'

    resources :builds, only: [:show] do
      post 'toggle-merge-on-success', :action => "toggle_merge_on_success", :on => :member, :as => :toggle_merge_on_success
      patch 'abort', :action => "abort", :on => :member
      get 'status', :action => "build_status", :on => :member, :defaults => { :format => 'json' }
      post 'rebuild-failed-parts', :action => "rebuild_failed_parts", :on => :member, :as => :rebuild_failed_parts
      post 'retry-partitioning', :action => "retry_partitioning", :on => :member, :as => :retry_partitioning
      get 'modified_time', :action => "modified_time", :on => :member, :defaults => { :format => 'json' }
      get 'refresh_build_part_info', :action => "refresh_build_part_info", :on => :member, :defaults => { :format => 'json' }
      post 'resend-status', :action => "resend_status",  :on => :member, :defaults => { :format => 'json' }

      resources :build_parts, as: 'parts', path: 'parts', only: [:show] do
        post 'rebuild', on: :member
        get 'modified_time', action: "modified_time", on: :member, defaults: { format: 'json' }
        get 'refresh_build_part_info', :action => "refresh_build_part_info", :on => :member, :defaults => { :format => 'json' }
      end
    end

    # override branch id to allow branch name to contain both slashes and dots
    resources :branches, path: "", only: [:index, :show], constraints: { id: /.+/ } do
      member do
        post 'request-new-build', action: "request_new_build"
        get 'build-time-history', action: "build_time_history", defaults: { format: 'json' }
        get 'health', action: 'health'
      end
      get 'status-report', action: "status_report", on: :collection
    end
  end
end
