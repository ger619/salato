Rails.application.routes.draw do
  devise_for :users, controllers:
    { sessions: 'sessions',
      invitations: 'invitations',
      registrations: 'registrations'
    }

  get "up" => "rails/health#show", as: :rails_health_check


  root "home#index"
  # config/routes.rb
  resources :users, only: %w[new create edit update show] do
    member do
      patch :status
    end
  end
  resources :dashboard, only: %w[index]
  resources :ticket_types, only: %w[index show]
  resources :users, only: %w[index new create show]
  namespace :onboarding do
    resources :clients
  end

  resources :events, param: :slug do
    collection do
      get :organiser          # index  → /events/organiser
    end
    member do
      get :organiser_show # show → /events/:slug/organiser_show
      post   :assign_user
      delete :unassign_user
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

  post "verify/lookup",
       to: "ticket_verifications#lookup",
       as: :lookup_verification


  get "/verify/:token",
      to: "ticket_verifications#show",
      as: :verify_ticket

  post "/verify/:token/check_in",
       to: "ticket_verifications#check_in",
       as: :check_in_ticket


end
