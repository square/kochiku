Kochiku::Application.routes.draw do
  root :to => "builds#index"

  mount Resque::Server.new, :at => '/resque'

  resources :projects do
    collection do
      get 'status-report', :action => 'status_report'
    end
    member do
      post 'push-receive-hook', :action => 'push_receive_hook'
    end
  end
  match '/XmlStatusReport.aspx', :to => "builds#status_report", :defaults => { :format => 'xml' }

  resources :builds do
    resources :build_parts do
      member do
        post 'rebuild'
      end
    end
  end

  resources :build_attempts, :only => :update do
    resources :build_artifacts, :only => :create
  end
end
