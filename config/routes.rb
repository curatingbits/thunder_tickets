Rails.application.routes.draw do
  # Authentication routes
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  # Password reset routes
  resources :password_resets, only: [:new, :create, :edit, :update]

  # User management routes
  resources :users do
    member do
      post :toggle_active
      get :invitation_url
      post :resend_invitation
    end
  end

  # Invitation acceptance routes
  get "accept_invitation/:token", to: "invitations#show", as: :accept_invitation
  patch "accept_invitation/:token", to: "invitations#update"

  # Buyers
  resources :buyers

  # Dashboard (root)
  root "dashboard#index"
  get "dashboard", to: "dashboard#index"

  # Games and tickets
  resources :games, only: [:index, :show, :edit, :update, :new, :create] do
    resources :tickets, only: [:create, :destroy]
  end

  # Season settings
  get "settings", to: "seasons#edit", as: :settings
  patch "settings", to: "seasons#update"

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
