Huginn::Application.routes.draw do
  resources :agents do
    member do
      post :run
      post :dry_run
      post :handle_details_post
      put :leave_scenario
      delete :remove_events
      delete :memory, action: :destroy_memory
    end

    collection do
      post :propagate
      get :type_details
      post :dry_run
      get :event_descriptions
      post :validate
      post :complete
    end

    resources :logs, :only => [:index] do
      collection do
        delete :clear
      end
    end

    resources :events, :only => [:index]
  end

  resource :diagram, :only => [:show]

  resources :events, :only => [:index, :show, :destroy] do
    member do
      post :reemit
    end
  end

  resources :scenarios do
    collection do
      resource :scenario_imports, :only => [:new, :create]
    end

    member do
      get :share
      get :export
    end

    resource :diagram, :only => [:show]
  end

  resources :user_credentials, :except => :show do
    collection do
      post :import
    end
  end

  resources :services, :only => [:index, :destroy] do
    member do
      post :toggle_availability
    end
  end

  resources :jobs, :only => [:index, :destroy] do
    member do
      put :run
    end
    collection do
      delete :destroy_failed
      delete :destroy_all
      post :retry_queued
    end
  end

  namespace :admin do
    resources :users, except: :show do
      member do
        put :deactivate
        put :activate
      end
    end
  end

  get "/worker_status" => "worker_status#show"

  match "/users/:user_id/web_requests/:agent_id/:secret" => "web_requests#handle_request", :as => :web_requests, :via => [:get, :post, :put, :delete]
  post  "/users/:user_id/webhooks/:agent_id/:secret" => "web_requests#handle_request" # legacy
  post  "/users/:user_id/update_location/:secret" => "web_requests#update_location" # legacy

  devise_for :users,
             controllers: { 
               omniauth_callbacks: 'omniauth_callbacks',
               registrations: 'users/registrations'
             },
             sign_out_via: [:post, :delete]
  
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  get "/about" => "home#about"
  root :to => "home#index"
end
