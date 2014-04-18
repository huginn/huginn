Huginn::Application.routes.draw do
  resources :agents do
    member do
      post :run
      post :handle_details_post
      delete :remove_events
    end

    collection do
      post :propagate
      get :type_details
      get :event_descriptions
      get :diagram
    end

    resources :logs, :only => [:index] do
      collection do
        delete :clear
      end
    end
  end

  resources :events, :only => [:index, :show, :destroy] do
    member do
      post :reemit
    end
  end

  resources :user_credentials, :except => :show

  get "/worker_status" => "worker_status#show"

  post "/users/:user_id/update_location/:secret" => "user_location_updates#create"

  match  "/users/:user_id/web_requests/:agent_id/:secret" => "web_requests#handle_request", :as => :web_requests, :via => [:get, :post, :put, :delete]
  post "/users/:user_id/webhooks/:agent_id/:secret" => "web_requests#handle_request" # legacy

# To enable DelayedJobWeb, see the 'Enable DelayedJobWeb' section of the README.
#  get "/delayed_job" => DelayedJobWeb, :anchor => false

  devise_for :users, :sign_out_via => [ :post, :delete ]

  get "/about" => "home#about"
  root :to => "home#index"
end
