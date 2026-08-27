Rails.application.routes.draw do
  devise_for :users, controllers: { invitations: 'invitations' }

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
  root "home#index"
  # config/routes.rb
  resource :session, only: %w[new create destroy]
  resources :users, only: %w[new create show]
  resources :dashboard, only: %w[index]
  resources :ticket_types, only: %w[index show]
  resources :users, only: %w[index new create show]
  resources :clients, only: %w[index new create show edit update]

  resources :events, param: :slug do
    collection do
      get :organiser          # index  → /events/organiser
    end
    member do
      get :organiser_show # show → /events/:slug/organiser_show
    end
    resources :orders, only: [:new, :create, :show] do
      member do
        get :initialize_payment
        get :download
      end
    end
  end

  get "/payments/:reference/callback",
      to: "payments#callback",
      as: :payment_callback

  post "/payments/paystack/webhook",
       to: "payments#webhook"

  resources :tickets, only: [:show] do
    member do
      get :download
    end
  end


  get "/verify",
      to: "ticket_verifications#new",
      as: :verify

  get "/verify/:token",
      to: "ticket_verifications#show",
      as: :verify_ticket

  post "/verify/:token/check_in",
       to: "ticket_verifications#check_in",
       as: :check_in_ticket


end
