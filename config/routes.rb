Kochiku::Application.routes.draw do
  root :to => "builds#index"

  mount Resque::Server.new, :at => '/resque'

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
